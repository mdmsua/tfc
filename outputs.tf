output "agent_pool_id" {
  description = "Agent pool ID"
  value       = tfe_agent_pool.main.id
}

output "published_app_ids" {
  description = "Published app IDs"
  value       = data.azuread_application_published_app_ids.main.result
}
