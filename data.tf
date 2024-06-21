data "tfe_organization" "main" {}

data "azurerm_client_config" "main" {}

data "azuread_client_config" "main" {}

data "azurerm_subscription" "main" {
  subscription_id = data.azurerm_client_config.main.subscription_id
}
