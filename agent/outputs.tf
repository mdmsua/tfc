output "ip_address" {
  description = "Egress IP address"
  value       = azurerm_container_group.main.ip_address
}
