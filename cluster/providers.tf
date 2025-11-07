terraform {
  required_version = "~> 1.0"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.51.0"
    }
    azuread = {
      source  = "hashicorp/azuread"
      version = "~> 3.6.0"
    }
    tfe = {
      source  = "hashicorp/tfe"
      version = "~> 0.70.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.7.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.38.0"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 3.1.0"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.1.0"
    }
    azapi = {
      source  = "azure/azapi"
      version = "~> 2.7.0"
    }
    github = {
      source  = "integrations/github"
      version = "~> 6.7.0"
    }
    kubectl = {
      source  = "gavinbunney/kubectl"
      version = "~> 1.19.0"
    }
  }
  cloud {
    organization = "dmmo"
    workspaces {
      name = "cluster"
    }
  }
}

provider "azurerm" {
  features {
    key_vault {
      purge_soft_delete_on_destroy    = true
      recover_soft_deleted_key_vaults = true
    }
    resource_group {
      prevent_deletion_if_contains_resources = false
    }
  }
  resource_provider_registrations = "none"
  client_id_file_path             = var.tfc_azure_dynamic_credentials.default.client_id_file_path
  oidc_token_file_path            = var.tfc_azure_dynamic_credentials.default.oidc_token_file_path
}

provider "tfe" {
  organization = "dmmo"
}

provider "azapi" {
  client_id_file_path  = var.tfc_azure_dynamic_credentials.default.client_id_file_path
  oidc_token_file_path = var.tfc_azure_dynamic_credentials.default.oidc_token_file_path
}

provider "azuread" {
  client_id_file_path  = var.tfc_azure_dynamic_credentials.default.client_id_file_path
  oidc_token_file_path = var.tfc_azure_dynamic_credentials.default.oidc_token_file_path
}

provider "kubernetes" {
  host                   = azurerm_kubernetes_cluster.main.kube_config[0].host
  cluster_ca_certificate = base64decode(azurerm_kubernetes_cluster.main.kube_config[0].cluster_ca_certificate)
  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "kubelogin"
    args = [
      "get-token",
      "--server-id",
      "6dae42f8-4368-4678-94ff-3960e28e3630",
      "-l",
      "msi"
    ]
  }
}

provider "helm" {
  kubernetes = {
    host                   = azurerm_kubernetes_cluster.main.kube_config[0].host
    cluster_ca_certificate = base64decode(azurerm_kubernetes_cluster.main.kube_config[0].cluster_ca_certificate)
    exec = {
      api_version = "client.authentication.k8s.io/v1beta1"
      command     = "kubelogin"
      args = [
        "get-token",
        "--server-id",
        "6dae42f8-4368-4678-94ff-3960e28e3630",
        "-l",
        "msi"
      ]
    }
  }
}

provider "kubectl" {
  host                   = azurerm_kubernetes_cluster.main.kube_config[0].host
  cluster_ca_certificate = base64decode(azurerm_kubernetes_cluster.main.kube_config[0].cluster_ca_certificate)
  load_config_file       = false
  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "kubelogin"
    args = [
      "get-token",
      "--server-id",
      "6dae42f8-4368-4678-94ff-3960e28e3630",
      "-l",
      "msi"
    ]
  }
}

provider "github" {}
