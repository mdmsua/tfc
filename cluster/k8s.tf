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

resource "azuread_application_password" "argocd" {
  application_id = azuread_application.argocd.id
}

resource "azurerm_key_vault_secret" "argocd_client_secret" {
  name         = "argocd-client-secret"
  value        = azuread_application_password.argocd.value
  key_vault_id = azurerm_key_vault.main.id

  depends_on = [azurerm_role_assignment.key_vault_administrator]
}

resource "azurerm_user_assigned_identity" "argocd" {
  name                = "${module.naming.user_assigned_identity.name}-argocd"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
}

resource "azurerm_federated_identity_credential" "argocd" {
  name                = azurerm_kubernetes_cluster.main.name
  resource_group_name = azurerm_kubernetes_cluster.main.node_resource_group
  parent_id           = azurerm_user_assigned_identity.argocd.id

  audience = ["api://AzureADTokenExchange"]
  issuer   = azurerm_kubernetes_cluster.main.oidc_issuer_url
  subject  = "system:serviceaccount:argocd:argocd-repo-server"
}

resource "azurerm_user_assigned_identity" "external_secrets" {
  name                = "${module.naming.user_assigned_identity.name}-external-secrets"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
}

resource "azurerm_federated_identity_credential" "external_secrets" {
  name                = azurerm_kubernetes_cluster.main.name
  resource_group_name = azurerm_kubernetes_cluster.main.node_resource_group
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
