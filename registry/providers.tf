terraform {
  required_version = "~> 1.0"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
    azapi = {
      source  = "azure/azapi"
      version = "~> 2.0"
    }
  }
  cloud {
    organization = "dmmo"
    workspaces {
      name    = "acr"
      project = "Azure"
    }
  }
}

provider "azurerm" {
  features {}
}

provider "azapi" {}
