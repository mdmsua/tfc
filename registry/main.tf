resource "azurerm_resource_group" "main" {
  name     = "mdmsua"
  location = "germanywestcentral"
}

resource "azurerm_container_registry" "main" {
  name                   = azurerm_resource_group.main.name
  resource_group_name    = azurerm_resource_group.main.name
  location               = azurerm_resource_group.main.location
  admin_enabled          = false
  anonymous_pull_enabled = false
  sku                    = "Basic"
}

resource "azurerm_container_registry_task" "agent" {
  name                  = "tfc-agent"
  container_registry_id = azurerm_container_registry.main.id

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
}

resource "azurerm_container_registry_task" "modsecurity" {
  name                  = "modsecurity"
  container_registry_id = azurerm_container_registry.main.id

  platform {
    os           = "Linux"
    architecture = "arm64"
  }

  docker_step {
    dockerfile_path      = "images/modsecurity/Dockerfile"
    context_path         = "https://github.com/mdmsua/tfc"
    context_access_token = var.github_token
    image_names          = ["modsecurity:${var.modsecurity_version}"]

    arguments = {
      VERSION = var.modsecurity_version
    }
  }

  timer_trigger {
    name     = "daily"
    schedule = "0 0 * * *"
  }
}

resource "azurerm_container_registry_task_schedule_run_now" "modsecurity" {
  container_registry_task_id = azurerm_container_registry_task.modsecurity.id
}

moved {
  from = azurerm_container_registry_task.main
  to   = azurerm_container_registry_task.agent
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
