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
}

resource "azurerm_role_assignment" "key_vault_secrets_officer" {
  role_definition_name = "Key Vault Secrets Officer"
  principal_id         = data.azurerm_client_config.main.object_id
  scope                = var.key_vault_id
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

resource "azurerm_key_vault_secret" "cloudflare_api_token" {
  name         = "cloudflare-api-token"
  key_vault_id = var.key_vault_id
  value        = var.cloudflare_api_token

  depends_on = [
    azurerm_role_assignment.key_vault_secrets_officer
  ]
}

resource "azurerm_key_vault_secret" "docker_hub_auth" {
  name         = "docker-hub-auth"
  key_vault_id = var.key_vault_id
  value        = base64encode("${var.docker_hub_username}:${var.docker_hub_token}")

  depends_on = [
    azurerm_role_assignment.key_vault_secrets_officer
  ]
}
