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

resource "azurerm_container_registry_task" "main" {
  name                  = "tfc-agent"
  container_registry_id = azurerm_container_registry.main.id

  platform {
    os           = "Linux"
    architecture = "arm64"
  }

  docker_step {
    dockerfile_path      = "image/Dockerfile"
    context_path         = "https://github.com/mdmsua/tfc"
    context_access_token = var.github_token
    image_names          = ["tfc-agent:latest"]
  }

  timer_trigger {
    name     = "daily"
    schedule = "0 0 * * *"
  }
}
