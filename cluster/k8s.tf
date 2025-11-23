resource "azurerm_user_assigned_identity" "cert_manager" {
  name                = "${module.naming.user_assigned_identity.name}-cert-manager"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
}

resource "azurerm_federated_identity_credential" "cert_manager" {
  resource_group_name = azurerm_resource_group.main.name
  parent_id           = azurerm_user_assigned_identity.cert_manager.id
  name                = azurerm_kubernetes_cluster.main.name

  audience = ["api://AzureADTokenExchange"]
  issuer   = azurerm_kubernetes_cluster.main.oidc_issuer_url
  subject  = "system:serviceaccount:cert-manager:cert-manager"
}

resource "random_uuid" "app" {}

data "azuread_client_config" "main" {}

resource "azuread_application" "argocd" {
  display_name            = "ArgoCD"
  group_membership_claims = ["SecurityGroup"]
  owners                  = [data.azuread_client_config.main.object_id]

  required_resource_access {
    resource_app_id = "00000003-0000-0000-c000-000000000000" # Microsoft Graph

    resource_access {
      id   = "e1fe6dd8-ba31-4d61-89e7-88639da4683d" # User.Read
      type = "Scope"
    }
  }

  optional_claims {
    access_token {
      name      = "groups"
      essential = true
    }

    id_token {
      name      = "groups"
      essential = true
    }
  }

  api {
    oauth2_permission_scope {
      admin_consent_description  = "Allow the application to access ArgoCD on behalf of the signed-in user."
      admin_consent_display_name = "Access ArgoCD"
      enabled                    = true
      id                         = random_uuid.app.result
      type                       = "User"
      user_consent_description   = "Allow the application to access ArgoCD on your behalf."
      user_consent_display_name  = "Access ArgoCD"
      value                      = "user_impersonation"
    }
  }

  web {
    redirect_uris = [
      "https://argocd.dmmo.io/auth/callback"
    ]
  }
  public_client {
    redirect_uris = [
      "http://localhost:8080/auth/callback"
    ]
  }
}

resource "azuread_application_federated_identity_credential" "argocd" {
  application_id = azuread_application.argocd.id
  issuer         = azurerm_kubernetes_cluster.main.oidc_issuer_url
  audiences      = ["api://AzureADTokenExchange"]
  subject        = "system:serviceaccount:argocd:argocd-server"
  display_name   = azurerm_kubernetes_cluster.main.name
}

resource "azuread_group" "argocd_admins" {
  display_name     = "ArgoCD Admins"
  owners           = [data.azuread_client_config.main.object_id]
  members          = var.admins
  security_enabled = true
}

resource "azurerm_user_assigned_identity" "external_secrets" {
  name                = "${module.naming.user_assigned_identity.name}-external-secrets"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
}

resource "azurerm_federated_identity_credential" "external_secrets" {
  name                = azurerm_kubernetes_cluster.main.name
  resource_group_name = azurerm_kubernetes_cluster.main.resource_group_name
  parent_id           = azurerm_user_assigned_identity.external_secrets.id

  audience = ["api://AzureADTokenExchange"]
  issuer   = azurerm_kubernetes_cluster.main.oidc_issuer_url
  subject  = "system:serviceaccount:external-secrets:external-secrets"
}

resource "azurerm_role_assignment" "external_secrets" {
  scope                = azurerm_key_vault.main.id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = azurerm_user_assigned_identity.external_secrets.principal_id
}

resource "helm_release" "argocd" {
  name             = "argocd"
  repository       = "https://argoproj.github.io/argo-helm/"
  chart            = "argo-cd"
  namespace        = "argocd"
  create_namespace = true
}

data "github_repository" "main" {
  full_name = var.repository_name
}

resource "tls_private_key" "repository" {
  algorithm = "ED25519"
}

resource "github_repository_deploy_key" "main" {
  repository = data.github_repository.main.name
  title      = "ArgoCD"
  key        = tls_private_key.repository.public_key_openssh
  read_only  = true
}

resource "kubernetes_secret_v1" "repository" {
  metadata {
    name      = data.github_repository.main.name
    namespace = helm_release.argocd.namespace
    labels = {
      "app.kubernetes.io/part-of"      = "argocd"
      "argocd.argoproj.io/secret-type" = "repository"
    }
  }
  data = {
    url           = "ssh://git@github.com/${var.repository_name}"
    project       = "default"
    sshPrivateKey = <<-EOT
      ${trimspace(tls_private_key.repository.private_key_openssh)}
    EOT
  }

  depends_on = [helm_release.argocd]
}

resource "kubectl_manifest" "seed" {
  yaml_body = templatefile("${path.module}/files/seed.yaml", {
    external_secrets_client_id = azurerm_user_assigned_identity.external_secrets.client_id
    key_vault_url              = azurerm_key_vault.main.vault_uri
    cloudflare_remote_key      = azurerm_key_vault_secret.cloudflare_api_token.name
    domain                     = var.domain
    oidc_tenant_id             = data.azurerm_client_config.main.tenant_id
    oidc_client_id             = azuread_application.argocd.client_id
    oidc_group_id              = azuread_group.argocd_admins.object_id
  })

  depends_on = [helm_release.argocd]
}
