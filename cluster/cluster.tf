resource "azurerm_disk_encryption_set" "main" {
  name                      = module.naming.disk_encryption_set.name
  location                  = azurerm_resource_group.main.location
  resource_group_name       = azurerm_resource_group.main.name
  key_vault_key_id          = azurerm_key_vault_key.cluster.versionless_id
  encryption_type           = "EncryptionAtRestWithPlatformAndCustomerKeys"
  auto_key_rotation_enabled = true

  identity {
    type = "SystemAssigned"
  }
}

resource "azurerm_role_assignment" "disk_encryption_set_key_vault_crypto_service_encryption_user" {
  role_definition_name = "Key Vault Crypto Service Encryption User"
  principal_id         = azurerm_disk_encryption_set.main.identity["0"].principal_id
  scope                = azurerm_key_vault_key.cluster.resource_versionless_id
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

resource "azurerm_role_assignment" "cluster_disk_encryption_set_reader" {
  principal_id         = azurerm_user_assigned_identity.cluster.principal_id
  role_definition_name = "Reader"
  scope                = azurerm_disk_encryption_set.main.id
}

resource "azurerm_kubernetes_cluster" "main" {
  name                              = module.naming.kubernetes_cluster.name
  location                          = azurerm_resource_group.main.location
  resource_group_name               = azurerm_resource_group.main.name
  node_resource_group               = "${azurerm_resource_group.main.name}-aks"
  dns_prefix                        = "dmmo"
  disk_encryption_set_id            = azurerm_disk_encryption_set.main.id
  kubernetes_version                = var.kubernetes_version
  sku_tier                          = "Standard"
  automatic_upgrade_channel         = "node-image"
  node_os_upgrade_channel           = "NodeImage"
  local_account_disabled            = true
  oidc_issuer_enabled               = true
  role_based_access_control_enabled = true
  workload_identity_enabled         = true
  azure_policy_enabled              = false
  http_application_routing_enabled  = false
  image_cleaner_enabled             = false
  open_service_mesh_enabled         = false
  run_command_enabled               = false

  network_profile {
    network_plugin      = "azure"
    network_plugin_mode = "overlay"
    network_data_plane  = "cilium"
    network_policy      = "cilium"
    ip_versions         = ["IPv4", "IPv6"]
    pod_cidrs           = ["172.16.0.0/16", "fd19:444d:4d4f::/48"]
    service_cidrs       = ["172.17.0.0/16", "fd20:444d:4d4f::/108"]
    dns_service_ip      = cidrhost("172.17.0.0/16", 10)
    load_balancer_sku   = "standard"

    load_balancer_profile {
      idle_timeout_in_minutes  = 4
      outbound_ports_allocated = 8192
      backend_pool_type        = "NodeIP"

      outbound_ip_address_ids = [
        azurerm_public_ip.ipv4.id,
        azurerm_public_ip.ipv6.id
      ]
    }
  }

  default_node_pool {
    name                        = "default"
    temporary_name_for_rotation = "temp"
    host_encryption_enabled     = true
    auto_scaling_enabled        = true
    min_count                   = 1
    max_count                   = 3
    max_pods                    = 64
    os_disk_size_gb             = 32
    os_sku                      = "AzureLinux"
    vm_size                     = "Standard_B2ps_v2"
    vnet_subnet_id              = azurerm_subnet.nodes.id
    orchestrator_version        = var.kubernetes_version

    upgrade_settings {
      max_surge = "100%"
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

  azure_active_directory_role_based_access_control {
    tenant_id          = data.azurerm_client_config.main.tenant_id
    azure_rbac_enabled = true
  }

  auto_scaler_profile {
    balance_similar_node_groups = true
  }

  api_server_access_profile {
    virtual_network_integration_enabled = true
    subnet_id                           = azurerm_subnet.api_server.id
  }

  lifecycle {
    ignore_changes = [
      network_profile["pod_cidrs"],
      network_profile["service_cidrs"],
    ]
  }

  depends_on = [
    azurerm_role_assignment.cluster_disk_encryption_set_reader,
  ]
}

resource "azurerm_role_assignment" "cluster_admins" {
  for_each             = toset(concat(var.admins, [data.azurerm_client_config.main.object_id]))
  role_definition_name = "Azure Kubernetes Service RBAC Cluster Admin"
  principal_id         = each.key
  scope                = azurerm_kubernetes_cluster.main.id
}

resource "azapi_update_resource" "preview_features" {
  type        = "Microsoft.ContainerService/managedClusters@2025-07-02-preview"
  resource_id = azurerm_kubernetes_cluster.main.id

  body = {
    properties = {
      networkProfile = {
        podLinkLocalAccess = "None"
      }
    }
  }

  depends_on = [
    azurerm_kubernetes_cluster.main,
  ]

  timeouts {
    create = "1h"
    update = "1h"
  }
}
