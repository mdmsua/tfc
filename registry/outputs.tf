output "id" {
  description = "Container registry ID"
  value       = azurerm_container_registry.main.id
}

output "server" {
  description = "Container registry server"
  value       = azurerm_container_registry.main.login_server
}

output "mirrors" {
  description = "Container registry mirrors"
  value       = keys(local.mirrors)
}

output "key_vault_id" {
  description = "Key vault ID"
  value       = azurerm_key_vault.main.id
}

output "key_vault_uri" {
  description = "Key vault URI"
  value       = azurerm_key_vault.main.vault_uri
}
