terraform {
  required_version = "~> 1.0"
  cloud {
    organization = "dmmo"
    workspaces {
      name = "flux"
    }
  }
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
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
}

provider "azurerm" {
  features {}
  resource_provider_registrations = "none"
  client_id_file_path             = var.tfc_azure_dynamic_credentials.default.client_id_file_path
  oidc_token_file_path            = var.tfc_azure_dynamic_credentials.default.oidc_token_file_path
}

provider "azapi" {}

provider "github" {
  owner = var.github_owner
  app_auth {
    id              = var.github_app_id
    installation_id = var.github_app_installation_id
    pem_file        = var.github_app_pem_file
  }
}
