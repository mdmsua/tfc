
data "azurerm_client_config" "main" {}

data "azurerm_subscription" "main" {
  subscription_id = data.azurerm_client_config.main.subscription_id
}

data "azurerm_container_registry" "main" {
  name                = split("-", data.azurerm_client_config.main.subscription_id)[0]
  resource_group_name = split("-", data.azurerm_client_config.main.subscription_id)[0]
}

resource "tfe_agent_pool" "main" {
  name = "Azure"
}

resource "tfe_agent_token" "main" {
  agent_pool_id = tfe_agent_pool.main.id
  description   = "Azure agent pool token"
}

module "naming" {
  source  = "Azure/naming/azurerm"
  version = "~> 0.4.0"
  suffix  = ["tfc", "gwc", "dev"]
}

resource "azurerm_resource_group" "main" {
  name     = module.naming.resource_group.name
  location = "germanywestcentral"
}

resource "azurerm_user_assigned_identity" "main" {
  name                = module.naming.user_assigned_identity.name
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
}

resource "azurerm_role_assignment" "subscription_owner" {
  role_definition_name = "Owner"
  principal_id         = azurerm_user_assigned_identity.main.principal_id
  scope                = data.azurerm_subscription.main.id
}

resource "azurerm_role_assignment" "cluster_admin" {
  role_definition_name = "Azure Kubernetes Service RBAC Cluster Admin"
  principal_id         = azurerm_user_assigned_identity.main.principal_id
  scope                = data.azurerm_subscription.main.id
}

resource "azurerm_role_assignment" "acr_pull" {
  role_definition_name = "AcrPull"
  principal_id         = azurerm_user_assigned_identity.main.principal_id
  scope                = data.azurerm_container_registry.main.id
}

resource "azurerm_container_group" "main" {
  name                = module.naming.container_group.name
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  sku                 = "Standard"
  os_type             = "Linux"
  ip_address_type     = "Public"
  restart_policy      = "Always"

  identity {
    type         = "UserAssigned"
    identity_ids = [azurerm_user_assigned_identity.main.id]
  }

  container {
    name   = "agent"
    image  = "${data.azurerm_container_registry.main.login_server}/tfc-agent:latest"
    cpu    = 1
    memory = 1

    ports {
      port     = 443
      protocol = "TCP"
    }

    secure_environment_variables = {
      TFC_AGENT_TOKEN = tfe_agent_token.main.token
    }

    environment_variables = {
      TFC_AGENT_NAME = "agent"
    }
  }

  image_registry_credential {
    server                    = data.azurerm_container_registry.main.login_server
    user_assigned_identity_id = azurerm_user_assigned_identity.main.id
  }

  depends_on = [azurerm_role_assignment.acr_pull]
}
