module "naming" {
  source  = "Azure/naming/azurerm"
  version = "0.4.3"
  suffix  = ["tfc", "sdc"]
}

data "azurerm_client_config" "main" {}

resource "azurerm_resource_group" "main" {
  name     = module.naming.resource_group.name
  location = "swedencentral"
}

data "tfe_outputs" "registry" {
  workspace = "registry"
}

locals {
  key_vault_id               = data.tfe_outputs.registry.nonsensitive_values.key_vault_id
  key_vault_uri              = data.tfe_outputs.registry.nonsensitive_values.key_vault_uri
  container_registry_id      = data.tfe_outputs.registry.nonsensitive_values.id
  container_registry_server  = data.tfe_outputs.registry.nonsensitive_values.server
  container_registry_mirrors = data.tfe_outputs.registry.nonsensitive_values.mirrors
}
