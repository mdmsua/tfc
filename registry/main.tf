resource "azurerm_resource_group" "main" {
  name     = "mdmsua"
  location = "germanywestcentral"
}

module "naming" {
  source  = "Azure/naming/azurerm"
  version = "0.4.2"
  suffix  = ["tfc", "gwc"]
}

locals {
  mirrors = {
    #docker.io         = true
    "mcr.microsoft.com" = false
    "quay.io"           = false
    "ghcr.io"           = false
    "public.ecr.aws"    = false
    "gcr.io"            = false
  }
}

resource "azurerm_container_registry" "main" {
  name                   = azurerm_resource_group.main.name
  resource_group_name    = azurerm_resource_group.main.name
  location               = azurerm_resource_group.main.location
  admin_enabled          = false
  anonymous_pull_enabled = false
  sku                    = "Basic"
}

resource "azurerm_container_registry_cache_rule" "main" {
  for_each              = local.mirrors
  container_registry_id = azurerm_container_registry.main.id
  name                  = replace(each.key, ".", "-")
  source_repo           = each.key
  target_repo           = each.key
}

resource "azurerm_key_vault" "main" {
  name                       = "mdmsua"
  location                   = azurerm_resource_group.main.location
  resource_group_name        = azurerm_resource_group.main.name
  tenant_id                  = data.azurerm_client_config.main.tenant_id
  sku_name                   = "standard"
  rbac_authorization_enabled = true
  purge_protection_enabled   = true
  soft_delete_retention_days = 7
}

resource "azurerm_user_assigned_identity" "push" {
  name                = "${module.naming.user_assigned_identity.name}-push"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
}

data "github_repository" "main" {
  name = "tfc"
}

resource "azurerm_federated_identity_credential" "push" {
  name                = "github"
  parent_id           = azurerm_user_assigned_identity.push.id
  resource_group_name = azurerm_user_assigned_identity.push.resource_group_name
  audience            = ["api://AzureADTokenExchange"]
  issuer              = "https://token.actions.githubusercontent.com"
  subject             = "repo:${data.github_repository.main.full_name}:ref:refs/heads/main"
}

resource "azurerm_container_registry_task" "agent" {
  name                  = "tfc-agent"
  container_registry_id = azurerm_container_registry.main.id

  identity {
    type = "SystemAssigned"
  }

  platform {
    os           = "Linux"
    architecture = "arm64"
  }

  docker_step {
    dockerfile_path      = "images/agent/Dockerfile"
    context_path         = "https://github.com/mdmsua/tfc"
    context_access_token = var.github_token
    image_names          = ["tfc-agent:latest"]
  }

  timer_trigger {
    name     = "daily"
    schedule = "0 0 * * *"
  }

  registry_credential {
    custom {
      login_server = azurerm_container_registry.main.login_server
      identity     = "[system]"
    }
  }
}

resource "azapi_update_resource" "registry_role_assignment_mode" {
  type        = "Microsoft.ContainerRegistry/registries@2025-04-01"
  resource_id = azurerm_container_registry.main.id
  body = {
    properties = {
      roleAssignmentMode = "AbacRepositoryPermissions"
    }
  }
}

resource "azurerm_role_assignment" "container_registry_repository_catalog_lister" {
  for_each = var.contributors

  scope                = azurerm_container_registry.main.id
  role_definition_name = "Container Registry Repository Catalog Lister"
  principal_id         = each.key
}

resource "azurerm_role_assignment" "container_registry_repository_contributor" {
  for_each = var.contributors

  scope                = azurerm_container_registry.main.id
  role_definition_name = "Container Registry Repository Contributor"
  principal_id         = each.key
}

resource "azurerm_role_assignment" "agent_container_registry_repository_writer" {
  scope                = azurerm_container_registry.main.id
  role_definition_name = "Container Registry Repository Writer"
  principal_id         = azurerm_container_registry_task.agent.identity[0].principal_id
  principal_type       = "ServicePrincipal"
  condition_version    = "2.0"
  condition            = <<EOF
  (
 (
  !(ActionMatches{'Microsoft.ContainerRegistry/registries/repositories/content/write'})
  AND
  !(ActionMatches{'Microsoft.ContainerRegistry/registries/repositories/metadata/write'})
 )
 OR 
 (
  @Request[Microsoft.ContainerRegistry/registries/repositories:name] StringEqualsIgnoreCase 'tfc-agent'
 )
)
EOF
}

resource "azurerm_role_assignment" "push_container_registry_repository_writer" {
  scope                = azurerm_container_registry.main.id
  role_definition_name = "Container Registry Repository Writer"
  principal_id         = azurerm_user_assigned_identity.push.principal_id
  principal_type       = "ServicePrincipal"
  condition_version    = "2.0"
  condition            = <<EOF
  (
 (
  !(ActionMatches{'Microsoft.ContainerRegistry/registries/repositories/content/write'})
  AND
  !(ActionMatches{'Microsoft.ContainerRegistry/registries/repositories/metadata/write'})
 )
 OR 
 (
  @Request[Microsoft.ContainerRegistry/registries/repositories:name] StringEqualsIgnoreCase 'modsecurity'
 )
)
EOF
}

resource "github_actions_secret" "docker" {
  repository      = data.github_repository.main.name
  secret_name     = "DOCKER_TOKEN"
  plaintext_value = var.docker_hub_token
}

data "azurerm_client_config" "main" {}

locals {
  actions_variables = {
    CLIENT_ID       = azurerm_user_assigned_identity.push.client_id
    TENANT_ID       = data.azurerm_client_config.main.tenant_id
    SUBSCRIPTION_ID = data.azurerm_client_config.main.subscription_id
    REGISTRY        = azurerm_container_registry.main.login_server
  }
  tfe_variables = {
    container_registry_id     = azurerm_container_registry.main.id
    container_registry_server = azurerm_container_registry.main.login_server
  }
}

resource "github_actions_variable" "main" {
  for_each = local.actions_variables

  repository    = data.github_repository.main.name
  variable_name = each.key
  value         = each.value
}

data "tfe_variable_set" "azure" {
  name = "Azure"
}

resource "tfe_variable" "azure" {
  for_each = local.tfe_variables

  category        = "terraform"
  key             = each.key
  value           = each.value
  variable_set_id = data.tfe_variable_set.azure.id
}
