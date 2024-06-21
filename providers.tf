terraform {
  required_version = "~> 1.8"
  cloud {
    organization = "dmmo"
    workspaces {
      name = "root"
    }
  }
  required_providers {
    tfe = {
      source  = "hashicorp/tfe"
      version = "~> 0.50"
    }
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }
    azuread = {
      source  = "hashicorp/azuread"
      version = "~> 2.0"
    }
  }
}

provider "tfe" {
  organization = "dmmo"
}

provider "azurerm" {
  features {}
  use_oidc                   = true
  skip_provider_registration = true
  client_id_file_path        = var.tfc_azure_dynamic_credentials.default.client_id_file_path
  oidc_token_file_path       = var.tfc_azure_dynamic_credentials.default.oidc_token_file_path
}

provider "azuread" {
  use_oidc             = true
  client_id_file_path  = var.tfc_azure_dynamic_credentials.default.client_id_file_path
  oidc_token_file_path = var.tfc_azure_dynamic_credentials.default.oidc_token_file_path
}
