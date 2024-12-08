locals {
  workspaces = { for f in fileset("${path.module}/workspaces", "*.yaml") : trimsuffix(f, ".yaml") => yamldecode(file("${path.module}/workspaces/${f}")) }
}

data "tfe_agent_pool" "main" {
  name = "Azure"
}

data "tfe_project" "main" {
  name = "Azure"
}

data "azuread_client_config" "main" {}

data "tfe_organization" "main" {}

data "tfe_github_app_installation" "main" {
  installation_id = 42695319
}

data "azuread_application" "main" {
  client_id = data.azuread_client_config.main.client_id
}

resource "tfe_workspace" "main" {
  for_each                       = local.workspaces
  name                           = each.key
  project_id                     = data.tfe_project.main.id
  allow_destroy_plan             = true
  auto_apply_run_trigger         = true
  auto_destroy_activity_duration = "6h"
  working_directory              = "root/workspaces/${each.key}"

  vcs_repo {
    identifier                 = "mdmsua/tfc"
    github_app_installation_id = data.tfe_github_app_installation.main.id
  }
}

resource "tfe_workspace_settings" "main" {
  for_each      = local.workspaces
  workspace_id  = tfe_workspace.main[each.key].id
  agent_pool_id = data.tfe_agent_pool.main.id
}

resource "azuread_application_federated_identity_credential" "plan" {
  for_each       = local.workspaces
  display_name   = "${each.key}-plan"
  application_id = data.azuread_application.main.id
  audiences      = ["api://AzureADTokenExchange"]
  issuer         = "https://app.terraform.io"
  subject        = "organization:${data.tfe_organization.main.name}:project:${data.tfe_project.main.name}:workspace:${each.key}:run_phase:plan"
}

resource "azuread_application_federated_identity_credential" "apply" {
  for_each       = local.workspaces
  display_name   = "${each.key}-apply"
  application_id = data.azuread_application.main.id
  audiences      = ["api://AzureADTokenExchange"]
  issuer         = "https://app.terraform.io"
  subject        = "organization:${data.tfe_organization.main.name}:project:${data.tfe_project.main.name}:workspace:${each.key}:run_phase:apply"
}

removed {
  from = azurerm_resource_group.main
  lifecycle {
    destroy = false
  }
}
