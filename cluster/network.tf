locals {
  address_space = ["192.168.224.0/27", "fd18:444d:4d4f::/48"]
}

resource "azurerm_virtual_network" "main" {
  name                = module.naming.virtual_network.name
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  address_space       = local.address_space
}

resource "azurerm_subnet" "api_server" {
  name                            = "${module.naming.subnet.name}-api-server"
  virtual_network_name            = azurerm_virtual_network.main.name
  resource_group_name             = azurerm_virtual_network.main.resource_group_name
  default_outbound_access_enabled = false

  address_prefixes = [
    cidrsubnet(local.address_space[0], 1, 0),
    cidrsubnet(local.address_space[1], 16, 0)
  ]

  delegation {
    name = "Microsoft.ContainerService/managedClusters"
    service_delegation {
      name    = "Microsoft.ContainerService/managedClusters"
      actions = ["Microsoft.Network/virtualNetworks/subnets/join/action"]
    }
  }
}

resource "azurerm_subnet" "nodes" {
  name                            = "${module.naming.subnet.name}-nodes"
  virtual_network_name            = azurerm_virtual_network.main.name
  resource_group_name             = azurerm_virtual_network.main.resource_group_name
  default_outbound_access_enabled = false

  address_prefixes = [
    cidrsubnet(local.address_space[0], 1, 1),
    cidrsubnet(local.address_space[1], 16, 1)
  ]

  service_endpoints = [
    "Microsoft.KeyVault",
  ]
}

resource "azurerm_network_security_group" "main" {
  name                = module.naming.network_security_group.name
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name

  security_rule {
    name                       = "AllowIngress"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "*"
    source_port_range          = "*"
    source_address_prefix      = "Internet"
    destination_address_prefix = "*"
    destination_port_ranges    = ["80", "443"]
  }
}

resource "azurerm_subnet_network_security_group_association" "main" {
  subnet_id                 = azurerm_subnet.nodes.id
  network_security_group_id = azurerm_network_security_group.main.id
}

resource "azurerm_public_ip" "ipv4" {
  name                = "${module.naming.public_ip.name}-ipv4"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  allocation_method   = "Static"
  ip_version          = "IPv4"
  zones               = ["1", "2", "3"]
}

resource "azurerm_public_ip" "ipv6" {
  name                = "${module.naming.public_ip.name}-ipv6"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  allocation_method   = "Static"
  ip_version          = "IPv6"
  zones               = ["1", "2", "3"]
}
