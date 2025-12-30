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
