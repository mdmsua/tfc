terraform {
  required_version = "~> 1.0"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
  }
}

resource "azurerm_key_vault_secret" "username" {
  key_vault_id = var.key_vault_id
  name         = "${replace(var.server, ".", "-")}-username"
  value        = var.username
}

resource "azurerm_key_vault_secret" "password" {
  key_vault_id = var.key_vault_id
  name         = "${replace(var.server, ".", "-")}-password"
  value        = var.password
}

resource "azurerm_container_registry_credential_set" "main" {
  name                  = replace(var.server, ".", "-")
  container_registry_id = var.container_registry_id
  login_server          = var.server

  identity {
    type = "SystemAssigned"
  }

  authentication_credentials {
    username_secret_id = azurerm_key_vault_secret.username.versionless_id
    password_secret_id = azurerm_key_vault_secret.password.versionless_id
  }
}

resource "azurerm_role_assignment" "credential_set_username_key_vault_secrets_user" {
  role_definition_name = "Key Vault Secrets User"
  principal_id         = azurerm_container_registry_credential_set.main.identity[0].principal_id
  scope                = azurerm_key_vault_secret.username.resource_versionless_id
}

resource "azurerm_role_assignment" "credential_set_password_key_vault_secrets_user" {
  role_definition_name = "Key Vault Secrets User"
  principal_id         = azurerm_container_registry_credential_set.main.identity[0].principal_id
  scope                = azurerm_key_vault_secret.password.resource_versionless_id
}
