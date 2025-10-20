

data "tfe_outputs" "registry" {
  workspace = "registry"
}

data "tfe_outputs" "root" {
  workspace = "root"
}

data "azurerm_container_registry" "main" {
  name                = provider::azurerm::parse_resource_id(data.tfe_outputs.registry.values.id).resource_name
  resource_group_name = provider::azurerm::parse_resource_id(data.tfe_outputs.registry.values.id).resource_group_name
}

resource "tfe_agent_token" "main" {
  agent_pool_id = data.tfe_outputs.root.values.agent_pool_id
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

resource "azurerm_role_assignment" "repository_reader" {
  scope                = data.azurerm_container_registry.main.id
  role_definition_name = "Container Registry Repository Reader"
  principal_id         = azurerm_user_assigned_identity.main.principal_id
  principal_type       = "ServicePrincipal"
  condition_version    = "2.0"
  condition            = <<EOF
(
 (
  !(ActionMatches{'Microsoft.ContainerRegistry/registries/repositories/content/read'})
  AND
  !(ActionMatches{'Microsoft.ContainerRegistry/registries/repositories/metadata/read'})
 )
 OR 
 (
  @Request[Microsoft.ContainerRegistry/registries/repositories:name] StringEqualsIgnoreCase 'tfc-agent'
 )
)
  EOF
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

  depends_on = [azurerm_role_assignment.repository_reader]
}
