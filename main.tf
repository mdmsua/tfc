resource "tfe_agent_pool" "main" {
  name                = "Azure"
  organization_scoped = true
}

resource "tfe_agent_token" "main" {
  agent_pool_id = tfe_agent_pool.main.id
  description   = "Azure agent pool token"
}

module "naming" {
  source  = "Azure/naming/azurerm"
  version = "~> 0.4"
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

resource "azurerm_role_assignment" "agent_subscription_owner" {
  role_definition_name = "Owner"
  principal_id         = azurerm_user_assigned_identity.main.principal_id
  scope                = data.azurerm_subscription.main.id
}

resource "azurerm_role_assignment" "agent_cluster_admin" {
  role_definition_name = "Azure Kubernetes Service RBAC Cluster Admin"
  principal_id         = azurerm_user_assigned_identity.main.principal_id
  scope                = data.azurerm_subscription.main.id
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
    image  = var.image
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
    server   = split("/", var.image)[0]
    username = split("/", var.image)[1]
    password = var.image_registry_password
  }
}
