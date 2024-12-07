data "azurerm_client_config" "main" {}

data "azurerm_resource_group" "main" {
  name = split("-", data.azurerm_client_config.main.subscription_id)[0]
}

resource "azurerm_container_registry" "main" {
  name                   = data.azurerm_resource_group.main.name
  resource_group_name    = data.azurerm_resource_group.main.name
  location               = data.azurerm_resource_group.main.location
  admin_enabled          = false
  anonymous_pull_enabled = false
  sku                    = "Basic"
}

resource "azurerm_container_registry_task" "main" {
  name                  = "tfc-agent"
  container_registry_id = azurerm_container_registry.main.id

  platform {
    os           = "Linux"
    architecture = "amd64"
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
