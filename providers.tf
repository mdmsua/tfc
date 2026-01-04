terraform {
  required_version = "~> 1.0"
  cloud {
    organization = "mdmsua"
    hostname     = "app.eu.terraform.io"
    workspaces {
      name = "root"
    }
  }
  required_providers {
    tfe = {
      source  = "hashicorp/tfe"
      version = "~> 0.72.0"
    }
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
    azuread = {
      source  = "hashicorp/azuread"
      version = "~> 3.0"
    }
  }
}

provider "tfe" {
  organization = "mdmsua"
}

provider "azurerm" {
  features {}
  resource_provider_registrations = "none"
  client_id_file_path             = var.tfc_azure_dynamic_credentials.default.client_id_file_path
  oidc_token_file_path            = var.tfc_azure_dynamic_credentials.default.oidc_token_file_path
}

provider "azuread" {
  client_id_file_path  = var.tfc_azure_dynamic_credentials.default.client_id_file_path
  oidc_token_file_path = var.tfc_azure_dynamic_credentials.default.oidc_token_file_path
}
