resource "azurerm_key_vault" "main" {
  name                          = module.naming.key_vault.name
  location                      = azurerm_resource_group.main.location
  resource_group_name           = azurerm_resource_group.main.name
  tenant_id                     = data.azurerm_client_config.main.tenant_id
  sku_name                      = "standard"
  public_network_access_enabled = true
  rbac_authorization_enabled    = true
  enabled_for_disk_encryption   = true
  purge_protection_enabled      = true
  soft_delete_retention_days    = 7

  network_acls {
    default_action             = "Deny"
    bypass                     = "AzureServices"
    virtual_network_subnet_ids = [data.tfe_outputs.agent.values.subnet_id]
  }
}

resource "azurerm_role_assignment" "key_vault_secrets_officer" {
  role_definition_name = "Key Vault Secrets Officer"
  principal_id         = data.azurerm_client_config.main.object_id
  scope                = local.key_vault_id
  principal_type       = "ServicePrincipal"
}

resource "azurerm_role_assignment" "key_vault_crypto_officer" {
  role_definition_name = "Key Vault Crypto Officer"
  principal_id         = data.azurerm_client_config.main.object_id
  scope                = azurerm_key_vault.main.id
  principal_type       = "ServicePrincipal"
}

resource "azurerm_key_vault_key" "cluster" {
  name         = "cluster"
  key_vault_id = azurerm_key_vault.main.id
  key_type     = "RSA"
  key_size     = 4096

  key_opts = [
    "unwrapKey",
    "wrapKey",
  ]

  depends_on = [
    azurerm_role_assignment.key_vault_crypto_officer,
  ]
}

resource "azurerm_key_vault_key" "storage" {
  name         = "storage"
  key_vault_id = azurerm_key_vault.main.id
  key_type     = "RSA"
  key_size     = 4096

  key_opts = [
    "unwrapKey",
    "wrapKey",
  ]

  depends_on = [
    azurerm_role_assignment.key_vault_crypto_officer,
  ]
}

locals {
  keys = {
    cloudflare_api_token       = "cloudflare-api-token"
    docker_hub_auth            = "docker-hub-auth"
    github_app_id              = "github-app-id"
    github_app_installation_id = "github-app-installation-id"
    github_app_pem_file        = "github-app-pem-file"
    storage_account_name       = "storage-account-name"
    storage_account_key        = "storage-account-key"
  }
  secrets = {
    (local.keys.cloudflare_api_token)       = var.cloudflare_api_token
    (local.keys.docker_hub_auth)            = base64encode("${var.docker_hub_username}:${var.docker_hub_token}")
    (local.keys.github_app_id)              = var.github_app_id
    (local.keys.github_app_installation_id) = var.github_app_installation_id
    (local.keys.github_app_pem_file)        = var.github_app_pem_file
    (local.keys.storage_account_name)       = azurerm_storage_account.main.name
    (local.keys.storage_account_key)        = azurerm_storage_account.main.primary_access_key
  }
}

resource "azurerm_key_vault_secret" "main" {
  for_each = local.secrets

  name         = each.key
  key_vault_id = local.key_vault_id
  value        = each.value

  depends_on = [
    azurerm_role_assignment.key_vault_secrets_officer
  ]
}
