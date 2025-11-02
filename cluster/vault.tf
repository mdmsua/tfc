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
    bypass         = "AzureServices"
    default_action = "Deny"
    ip_rules       = [data.tfe_outputs.agent.values.ip_address]
  }
}

resource "azurerm_role_assignment" "key_vault_administrator" {
  role_definition_name = "Key Vault Administrator"
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
    azurerm_role_assignment.key_vault_administrator,
  ]
}