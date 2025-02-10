module "naming" {
  source  = "Azure/naming/azurerm"
  version = "~> 0.4.0"
  suffix  = ["flux", "sdc"]
}

locals {
  network_cidrs = ["192.168.224.0/27", "fdff:646d:6d6f::/56"]
  pod_cidrs     = ["10.0.0.0/16", "fdff:646d:6d6f:100:/64"]
  service_cidrs = ["10.0.0.0/16", "fdff:646d:6d6f:200:/108"]
  zones         = ["1", "2", "3"]
}

data "azurerm_client_config" "main" {}

resource "azurerm_resource_group" "main" {
  name     = module.naming.resource_group.name
  location = "swedencentral"
}

resource "azurerm_virtual_network" "main" {
  name                = module.naming.virtual_network.name
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  address_space       = local.network_cidrs
}

resource "azurerm_subnet" "node" {
  name                 = "${module.naming.subnet.name}-node"
  resource_group_name  = azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.main.name

  address_prefixes = [
    cidrsubnet(local.network_cidrs[0], 1, 0),
    cidrsubnet(local.network_cidrs[1], 8, 0),
  ]
}

resource "azurerm_subnet" "kube" {
  name                 = "${module.naming.subnet.name}-kube"
  resource_group_name  = azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.main.name

  address_prefixes = [
    cidrsubnet(local.network_cidrs[0], 1, 1),
    cidrsubnet(local.network_cidrs[1], 8, 63),
  ]

  delegation {
    name = "Microsoft.ContainerService/managedClusters"
    service_delegation {
      name    = "Microsoft.ContainerService/managedClusters"
      actions = ["Microsoft.Network/virtualNetworks/subnets/join/action"]
    }
  }
}

resource "azurerm_public_ip" "ipv4" {
  name                = "${module.naming.public_ip.name}-ipv4"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  allocation_method   = "Static"
  ip_version          = "IPv4"
  sku                 = "Standard"
  zones               = local.zones
}

resource "azurerm_public_ip" "ipv6" {
  name                = "${module.naming.public_ip.name}-ipv6"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  allocation_method   = "Static"
  ip_version          = "IPv6"
  sku                 = "Standard"
  zones               = local.zones
}

resource "azurerm_user_assigned_identity" "cluster" {
  name                = "${module.naming.user_assigned_identity.name}-cluster"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
}

resource "azurerm_user_assigned_identity" "kubelet" {
  name                = "${module.naming.user_assigned_identity.name}-kubelet"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
}

resource "azurerm_role_assignment" "cluster_managed_identity_operator_kubelet" {
  principal_id         = azurerm_user_assigned_identity.cluster.principal_id
  role_definition_name = "Managed Identity Operator"
  scope                = azurerm_user_assigned_identity.kubelet.id
}

resource "azurerm_role_assignment" "cluster_network_contributor" {
  principal_id         = azurerm_user_assigned_identity.cluster.principal_id
  role_definition_name = "Network Contributor"
  scope                = azurerm_resource_group.main.id
}

resource "azurerm_kubernetes_cluster" "main" {
  name                              = module.naming.kubernetes_cluster.name
  resource_group_name               = azurerm_resource_group.main.name
  node_resource_group               = "${azurerm_resource_group.main.name}-aks"
  location                          = azurerm_resource_group.main.location
  sku_tier                          = "Standard"
  automatic_upgrade_channel         = "node-image"
  node_os_upgrade_channel           = "NodeImage"
  dns_prefix                        = "flux"
  kubernetes_version                = "1.31"
  local_account_disabled            = true
  oidc_issuer_enabled               = true
  role_based_access_control_enabled = true
  workload_identity_enabled         = true

  image_cleaner_enabled            = false
  http_application_routing_enabled = false
  run_command_enabled              = false
  azure_policy_enabled             = false
  open_service_mesh_enabled        = false

  network_profile {
    network_plugin      = "azure"
    network_plugin_mode = "overlay"
    network_data_plane  = "cilium"
    network_policy      = "cilium"
    load_balancer_sku   = "standard"
    ip_versions         = ["IPv4", "IPv6"]
    pod_cidrs           = local.pod_cidrs
    service_cidrs       = local.service_cidrs
    dns_service_ip      = cidrhost(local.service_cidrs[0], 10)

    load_balancer_profile {
      idle_timeout_in_minutes  = 4
      outbound_ports_allocated = 64000
      backend_pool_type        = "NodeIP"

      outbound_ip_address_ids = [
        azurerm_public_ip.ipv4.id,
        azurerm_public_ip.ipv6.id
      ]
    }
  }

  kubelet_identity {
    client_id                 = azurerm_user_assigned_identity.kubelet.client_id
    object_id                 = azurerm_user_assigned_identity.kubelet.principal_id
    user_assigned_identity_id = azurerm_user_assigned_identity.kubelet.id
  }

  identity {
    type         = "UserAssigned"
    identity_ids = [azurerm_user_assigned_identity.cluster.id]
  }

  default_node_pool {
    name                        = "default"
    temporary_name_for_rotation = "temp"
    host_encryption_enabled     = true
    auto_scaling_enabled        = true
    min_count                   = 1
    max_count                   = 3
    max_pods                    = 64
    os_disk_size_gb             = 64
    os_disk_type                = "Ephemeral"
    os_sku                      = "AzureLinux"
    vm_size                     = "Standard_D2pds_v6"
    vnet_subnet_id              = azurerm_subnet.node.id
    zones                       = local.zones

    upgrade_settings {
      max_surge = "100%"
    }
  }

  azure_active_directory_role_based_access_control {
    tenant_id          = data.azurerm_client_config.main.tenant_id
    azure_rbac_enabled = true
  }

  auto_scaler_profile {
    balance_similar_node_groups = true
  }

  maintenance_window {
    allowed {
      day   = "Saturday"
      hours = range(18, 0)
    }
    allowed {
      day   = "Sunday"
      hours = range(6, 18)
    }
  }

  maintenance_window_node_os {
    frequency   = "Weekly"
    interval    = 1
    duration    = 4
    day_of_week = "Sunday"
    start_time  = "06:00"
  }

  maintenance_window_auto_upgrade {
    frequency   = "Weekly"
    interval    = 1
    duration    = 4
    day_of_week = "Sunday"
    start_time  = "10:00"
  }
}

resource "azapi_update_resource" "kube" {
  type        = "Microsoft.ContainerService/managedClusters@2024-05-02-preview"
  resource_id = azurerm_kubernetes_cluster.main.id

  body = {
    properties = {
      apiServerAccessProfile = {
        enableVnetIntegration = true
        subnetId              = azurerm_subnet.kube.id
      }
    }
  }

  depends_on = [
    azurerm_kubernetes_cluster.main
  ]
}

resource "azurerm_role_assignment" "admin" {
  for_each             = concat([data.azurerm_client_config.main.object_id], tolist(var.principals))
  role_definition_name = "Azure Kubernetes Service RBAC Cluster Admin"
  scope                = azurerm_kubernetes_cluster.main.id
  principal_id         = each.key
}

resource "azurerm_role_assignment" "user" {
  for_each             = var.principals
  role_definition_name = "Azure Kubernetes Service Cluster User"
  scope                = azurerm_kubernetes_cluster.main.id
  principal_id         = each.key
}

resource "azurerm_kubernetes_cluster_extension" "flux" {
  name           = "flux"
  cluster_id     = azurerm_kubernetes_cluster.main.id
  extension_type = "microsoft.flux"
}

resource "azurerm_kubernetes_flux_configuration" "main" {
  name       = "flux"
  namespace  = "flux"
  cluster_id = azurerm_kubernetes_cluster.main.id

  git_repository {
    url                    = "https://github.com/mdmsua/flux"
    reference_type         = "branch"
    reference_value        = "main"
    ssh_private_key_base64 = base64encode(tls_private_key.main.private_key_openssh)
  }

  kustomizations {
    name                       = "default"
    garbage_collection_enabled = true
  }

  depends_on = [azurerm_kubernetes_cluster_extension.flux]
}

resource "tls_private_key" "main" {
  algorithm = "ED25519"
}

resource "github_repository_deploy_key" "main" {
  title      = "flux"
  repository = "flux"
  read_only  = true
  key        = tls_private_key.main.public_key_openssh
}
