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

resource "azurerm_user_assigned_identity" "argocd" {
  name                = "${module.naming.user_assigned_identity.name}-argocd"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
}

resource "azurerm_federated_identity_credential" "argocd" {
  name                = azurerm_kubernetes_cluster.main.name
  resource_group_name = azurerm_kubernetes_cluster.main.resource_group_name
  issuer              = azurerm_kubernetes_cluster.main.oidc_issuer_url
  audience            = ["api://AzureADTokenExchange"]
  parent_id           = azurerm_user_assigned_identity.argocd.id
  subject             = "system:serviceaccount:argocd:argocd"
}

resource "azurerm_user_assigned_identity" "argocd_server" {
  name                = "${module.naming.user_assigned_identity.name}-argocd-server"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
}

resource "azurerm_federated_identity_credential" "argocd_server" {
  name                = azurerm_kubernetes_cluster.main.name
  resource_group_name = azurerm_kubernetes_cluster.main.resource_group_name
  issuer              = azurerm_kubernetes_cluster.main.oidc_issuer_url
  audience            = ["api://AzureADTokenExchange"]
  parent_id           = azurerm_user_assigned_identity.argocd_server.id
  subject             = "system:serviceaccount:argocd:argocd-server"
}

resource "azurerm_user_assigned_identity" "argocd_application_controller" {
  name                = "${module.naming.user_assigned_identity.name}-argocd-application-controller"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
}

resource "azurerm_federated_identity_credential" "argocd_application_controller" {
  name                = azurerm_kubernetes_cluster.main.name
  resource_group_name = azurerm_kubernetes_cluster.main.resource_group_name
  issuer              = azurerm_kubernetes_cluster.main.oidc_issuer_url
  audience            = ["api://AzureADTokenExchange"]
  parent_id           = azurerm_user_assigned_identity.argocd_application_controller.id
  subject             = "system:serviceaccount:argocd:argocd-application-controller"
}

resource "azurerm_user_assigned_identity" "argocd_applicationset_controller" {
  name                = "${module.naming.user_assigned_identity.name}-argocd-applicationset-controller"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
}

resource "azurerm_federated_identity_credential" "argocd_applicationset_controller" {
  name                = azurerm_kubernetes_cluster.main.name
  resource_group_name = azurerm_kubernetes_cluster.main.resource_group_name
  issuer              = azurerm_kubernetes_cluster.main.oidc_issuer_url
  audience            = ["api://AzureADTokenExchange"]
  parent_id           = azurerm_user_assigned_identity.argocd_applicationset_controller.id
  subject             = "system:serviceaccount:argocd:argocd-applicationset-controller"
}

resource "azurerm_user_assigned_identity" "argocd_repo_server" {
  name                = "${module.naming.user_assigned_identity.name}-argocd-repo-server"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
}

resource "azurerm_federated_identity_credential" "argocd_repo_server" {
  name                = azurerm_kubernetes_cluster.main.name
  resource_group_name = azurerm_kubernetes_cluster.main.resource_group_name
  issuer              = azurerm_kubernetes_cluster.main.oidc_issuer_url
  audience            = ["api://AzureADTokenExchange"]
  parent_id           = azurerm_user_assigned_identity.argocd_repo_server.id
  subject             = "system:serviceaccount:argocd:argocd-repo-server"
}

resource "helm_release" "argocd" {
  name             = "argocd"
  repository       = "https://argoproj.github.io/argo-helm/"
  chart            = "argo-cd"
  namespace        = "argocd"
  version          = var.argocd_version
  create_namespace = true

  values = [
    templatefile("${path.module}/files/argocd.yaml", {
      server_client_id         = azurerm_user_assigned_identity.argocd_server.client_id
      controller_client_id     = azurerm_user_assigned_identity.argocd_application_controller.client_id
      applicationset_client_id = azurerm_user_assigned_identity.argocd_applicationset_controller.client_id
      repo_server_client_id    = azurerm_user_assigned_identity.argocd_repo_server.client_id
      oidc_tenant_id           = data.azurerm_client_config.main.tenant_id
      oidc_client_id           = azuread_application.argocd.client_id
    })
  ]
}

data "github_repository" "main" {
  name = "tfc"
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
      "argocd.argoproj.io/secret-type" = "repo-creds"
    }
  }
  data = {
    url           = data.github_repository.main.ssh_clone_url
    type          = "helm"
    project       = "default"
    sshPrivateKey = <<-EOT
      ${trimspace(tls_private_key.repository.private_key_openssh)}
    EOT
  }

  depends_on = [helm_release.argocd]
}

resource "kubernetes_secret_v1" "cluster" {
  metadata {
    name      = azurerm_kubernetes_cluster.main.name
    namespace = helm_release.argocd.namespace
    labels = {
      "app.kubernetes.io/part-of"      = "argocd"
      "argocd.argoproj.io/secret-type" = "cluster"
    }
  }
  data = {
    name   = azurerm_kubernetes_cluster.main.name
    server = azurerm_kubernetes_cluster.main.kube_config[0].host
    config = <<-EOT
    {
      execProviderConfig = {
        command = "argocd-k8s-auth",
        env = {
          AAD_LOGIN_METHOD           = "workloadidentity"
          AZURE_AUTHORITY_HOST       = "https://login.microsoftonline.com/",
          AZURE_FEDERATED_TOKEN_FILE = "/var/run/secrets/azure/tokens/azure-identity-token",
        },
        args       = ["azure"],
        apiVersion = "client.authentication.k8s.io/v1beta1"
      },
      tlsClientConfig = {
        insecure = false,
        caData   = "${azurerm_kubernetes_cluster.main.kube_config[0].cluster_ca_certificate}"
      }
    }
    EOT
  }

  depends_on = [helm_release.argocd]
}

# resource "helm_release" "apps" {
#   name             = "apps"
#   repository       = "https://bedag.github.io/helm-charts/"
#   chart            = "raw"
#   version          = "2.0.0"
#   namespace        = helm_release.argocd.namespace
#   create_namespace = false

#   values = [<<-EOT
#     resources:
#       - ${indent(4, file("${path.module}/files/appproject.yaml"))}
#   EOT
#   ]

#   depends_on = [helm_release.argocd]
# }
