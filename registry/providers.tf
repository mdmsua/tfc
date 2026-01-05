terraform {
  required_version = "~> 1.0"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
    tfe = {
      source  = "hashicorp/tfe"
      version = "~> 0.72.0"
    }
    azapi = {
      source  = "azure/azapi"
      version = "~> 2.0"
    }
    github = {
      source  = "integrations/github"
      version = "~> 6.0"
    }

  }
  cloud {
    workspaces {
      name = "registry"
    }
  }
}

provider "azurerm" {
  features {}
}

provider "tfe" {}

provider "azapi" {}

provider "github" {
  owner = var.github_owner
  app_auth {
    id              = var.github_app_id
    installation_id = var.github_app_installation_id
    pem_file        = var.github_app_pem_file
  }
}
