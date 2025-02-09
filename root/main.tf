locals {
  workspaces = { for f in fileset("${path.module}/workspaces", "*.yaml") : trimsuffix(f, ".yaml") => yamldecode(file("${path.module}/workspaces/${f}")) }
}

data "tfe_agent_pool" "main" {
  name = "Azure"
}

data "tfe_project" "main" {
  name = "Azure"
}

data "tfe_organization" "main" {}

data "azurerm_client_config" "main" {}

resource "tfe_workspace" "main" {
  for_each                       = local.workspaces
  name                           = each.key
  project_id                     = data.tfe_project.main.id
  allow_destroy_plan             = true
  auto_apply_run_trigger         = true
  auto_destroy_activity_duration = "6h"
  working_directory              = "root/workspaces/${each.key}"

  vcs_repo {
    identifier     = "mdmsua/tfc"
    branch         = "main"
    oauth_token_id = "ot-LtULrZJ8rQraLxoj"
  }
}

resource "tfe_workspace_settings" "main" {
  for_each      = local.workspaces
  workspace_id  = tfe_workspace.main[each.key].id
  agent_pool_id = data.tfe_agent_pool.main.id
}

module "naming" {
  source  = "Azure/naming/azurerm"
  version = "0.4.2"
  suffix  = ["tfc", "sdc"]
}

resource "azurerm_resource_group" "main" {
  name     = module.naming.resource_group.name
  location = "swedencentral"
}

resource "azurerm_user_assigned_identity" "main" {
  for_each            = local.workspaces
  name                = "${module.naming.user_assigned_identity.name}-${each.key}"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
}

resource "azurerm_federated_identity_credential" "plan" {
  for_each            = local.workspaces
  name                = "${each.key}-plan"
  resource_group_name = azurerm_user_assigned_identity.main[each.key].resource_group_name
  parent_id           = azurerm_user_assigned_identity.main[each.key].id
  audience            = ["api://AzureADTokenExchange"]
  issuer              = "https://app.terraform.io"
  subject             = "organization:${data.tfe_organization.main.name}:project:${data.tfe_project.main.name}:workspace:${each.key}:run_phase:plan"
}

resource "azurerm_federated_identity_credential" "apply" {
  for_each            = local.workspaces
  name                = "${each.key}-apply"
  resource_group_name = azurerm_user_assigned_identity.main[each.key].resource_group_name
  parent_id           = azurerm_user_assigned_identity.main[each.key].id
  audience            = ["api://AzureADTokenExchange"]
  issuer              = "https://app.terraform.io"
  subject             = "organization:${data.tfe_organization.main.name}:project:${data.tfe_project.main.name}:workspace:${each.key}:run_phase:apply"
}

resource "azurerm_role_assignment" "main" {
  for_each             = local.workspaces
  principal_id         = azurerm_user_assigned_identity.main[each.key].principal_id
  scope                = "/subscriptions/${data.azurerm_client_config.main.subscription_id}"
  role_definition_name = "Owner"
}

resource "tfe_variable_set" "main" {
  for_each          = local.workspaces
  name              = title(each.key)
  parent_project_id = data.tfe_project.main.id
  organization      = data.tfe_project.main.name
  workspace_ids     = [tfe_workspace.main[each.key].id]
}

resource "tfe_variable" "main" {
  for_each        = local.workspaces
  variable_set_id = tfe_variable_set.main[each.key].id
  key             = "ARM_CLIENT_ID"
  value           = azurerm_user_assigned_identity.main[each.key].client_id
  category        = "env"
}
