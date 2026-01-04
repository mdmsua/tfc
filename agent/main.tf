

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

data "azurerm_client_config" "main" {}

data "azurerm_subscription" "main" {
  subscription_id = data.azurerm_client_config.main.subscription_id
}

resource "tfe_agent_token" "main" {
  agent_pool_id = data.tfe_outputs.root.values.agent_pool_id
  description   = "Azure agent pool token"
}

module "naming" {
  source  = "Azure/naming/azurerm"
  version = "~> 0.4.0"
  suffix  = ["tfc", "gwc"]
}

resource "azurerm_resource_group" "main" {
  name     = module.naming.resource_group.name
  location = "germanywestcentral"
}

resource "azurerm_virtual_network" "main" {
  name                = module.naming.virtual_network.name
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  address_space       = ["192.168.255.248/29"]
}

resource "azurerm_subnet" "main" {
  name                            = module.naming.subnet.name
  resource_group_name             = azurerm_resource_group.main.name
  virtual_network_name            = azurerm_virtual_network.main.name
  address_prefixes                = azurerm_virtual_network.main.address_space
  default_outbound_access_enabled = false
  service_endpoints               = ["Microsoft.ContainerRegistry", "Microsoft.Storage", "Microsoft.KeyVault"]
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

resource "azurerm_role_assignment" "aks_rbac_cluster_admin" {
  scope                = data.azurerm_subscription.main.id
  role_definition_name = "Azure Kubernetes Service RBAC Cluster Admin"
  principal_id         = azurerm_user_assigned_identity.main.principal_id
  principal_type       = "ServicePrincipal"
}

resource "azurerm_container_group" "main" {
  name                = module.naming.container_group.name
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  sku                 = "Standard"
  os_type             = "Linux"
  ip_address_type     = "Private"
  restart_policy      = "Always"
  subnet_ids          = [azurerm_subnet.main.id]

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
