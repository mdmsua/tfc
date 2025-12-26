locals {
  workspaces = { for f in fileset("${path.module}/workspaces", "*.yaml") : trimsuffix(f, ".yaml") => yamldecode(file("${path.module}/workspaces/${f}")) }

  resource_providers = {
    "Microsoft.ContainerService" = ["EnableAPIServerVnetIntegrationPreview", "AzureOverlayDualStackPreview", "IMDSRestrictionPreview"]
    "Microsoft.Compute"          = ["EncryptionAtHost"]
  }
}

data "tfe_project" "main" {
  name = "Azure"
}

data "tfe_organization" "main" {}

data "azurerm_client_config" "main" {}

resource "tfe_variable_set" "main" {
  name = "Azure"
}

resource "tfe_project_variable_set" "main" {
  project_id      = data.tfe_project.main.id
  variable_set_id = tfe_variable_set.main.id
}

resource "tfe_workspace" "main" {
  for_each                       = local.workspaces
  name                           = each.key
  project_id                     = data.tfe_project.main.id
  allow_destroy_plan             = true
  auto_apply_run_trigger         = true
  auto_destroy_activity_duration = lookup(each.value, "ttl", null)
  working_directory              = lookup(each.value, "directory", each.key)
  terraform_version              = "~> 1.14.0"
  auto_apply                     = true
  trigger_patterns               = ["/${lookup(each.value, "directory", each.key)}"]

  vcs_repo {
    identifier                 = "mdmsua/tfc"
    github_app_installation_id = "ghain-h96Ax4WhkEsc8N96"
  }
}

module "naming" {
  source  = "Azure/naming/azurerm"
  version = "0.4.2"
  suffix  = ["tfc", "gwc"]
}

resource "azurerm_resource_group" "main" {
  name     = module.naming.resource_group.name
  location = "germanywestcentral"
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

resource "azurerm_resource_provider_registration" "main" {
  for_each = local.resource_providers
  name     = each.key

  dynamic "feature" {
    for_each = toset(each.value)
    content {
      name       = feature.value
      registered = true
    }
  }
}

resource "tfe_agent_pool" "main" {
  name = "Azure"
}

resource "tfe_agent_pool_allowed_workspaces" "main" {
  agent_pool_id         = tfe_agent_pool.main.id
  allowed_workspace_ids = [for k, v in local.workspaces : tfe_workspace.main[k].id if lookup(v, "agent", false)]
}

resource "tfe_workspace_settings" "main" {
  for_each = { for k, v in local.workspaces : k => v if lookup(v, "agent", false) }

  agent_pool_id  = tfe_agent_pool.main.id
  workspace_id   = tfe_workspace.main[each.key].id
  execution_mode = "agent"
}

resource "tfe_variable" "arm_client_id" {
  for_each     = local.workspaces
  key          = "ARM_CLIENT_ID"
  value        = azurerm_user_assigned_identity.main[each.key].client_id
  workspace_id = tfe_workspace.main[each.key].id
  category     = "env"
}

resource "tfe_variable" "tfc_azure_run_client_id" {
  for_each     = local.workspaces
  key          = "TFC_AZURE_RUN_CLIENT_ID"
  value        = azurerm_user_assigned_identity.main[each.key].client_id
  workspace_id = tfe_workspace.main[each.key].id
  category     = "env"
}

module "assignment" {
  source = "./modules/assignment"

  for_each = { for k, v in local.workspaces : k => v if contains(keys(v), "roles") }

  principal_id = azurerm_user_assigned_identity.main[each.key].principal_id
  roles        = each.value.roles
}
