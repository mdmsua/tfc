resource "azurerm_user_assigned_identity" "storage" {
  name                = "${module.naming.user_assigned_identity.name}-storage"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
}

resource "azurerm_role_assignment" "storage_key_vault_crypto_service_encryption_user" {
  role_definition_name = "Key Vault Crypto Service Encryption User"
  principal_id         = azurerm_user_assigned_identity.storage.principal_id
  scope                = azurerm_key_vault_key.storage.resource_versionless_id
}

resource "azurerm_storage_account" "main" {
  name                            = module.naming.storage_account.name
  resource_group_name             = azurerm_resource_group.main.name
  location                        = azurerm_resource_group.main.location
  account_tier                    = "Premium"
  account_kind                    = "FileStorage"
  account_replication_type        = "LRS"
  https_traffic_only_enabled      = true
  min_tls_version                 = "TLS1_2"
  allow_nested_items_to_be_public = false
  local_user_enabled              = false

  identity {
    type         = "UserAssigned"
    identity_ids = [azurerm_user_assigned_identity.storage.id]
  }

  network_rules {
    default_action = "Deny"
    bypass         = ["AzureServices"]
    virtual_network_subnet_ids = [
      azurerm_subnet.nodes.id,
      data.tfe_outputs.agent.values.subnet_id,
    ]
  }

  customer_managed_key {
    user_assigned_identity_id = azurerm_user_assigned_identity.storage.id
    key_vault_key_id          = azurerm_key_vault_key.storage.versionless_id
  }
}

resource "azurerm_storage_share" "main" {
  name               = "default"
  enabled_protocol   = "NFS"
  quota              = 1
  storage_account_id = azurerm_storage_account.main.id
}

resource "azurerm_storage_share_directory" "github" {
  name             = "github"
  storage_share_id = azurerm_storage_share.main.id
}
