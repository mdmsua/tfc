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
  }
}

provider "azurerm" {
  features {}
  resource_provider_registrations = "none"
  client_id_file_path             = var.tfc_azure_dynamic_credentials.default.client_id_file_path
  oidc_token_file_path            = var.tfc_azure_dynamic_credentials.default.oidc_token_file_path
}
