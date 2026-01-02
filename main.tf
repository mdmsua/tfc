locals {
  workspaces = { for f in fileset("${path.module}/workspaces", "*.yaml") : trimsuffix(f, ".yaml") => yamldecode(file("${path.module}/workspaces/${f}")) }

  resource_providers = {
    "Microsoft.ContainerService" = ["EnableAPIServerVnetIntegrationPreview", "AzureOverlayDualStackPreview", "IMDSRestrictionPreview"]
    "Microsoft.Compute"          = ["EncryptionAtHost"]
  }

  run_phases = toset(["plan", "apply"])
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
  trigger_patterns               = ["${lookup(each.value, "directory", each.key)}/**/*"]

  vcs_repo {
    identifier                 = "mdmsua/tfc"
    github_app_installation_id = "ghain-h96Ax4WhkEsc8N96"
  }
}

module "naming" {
  source  = "Azure/naming/azurerm"
  version = "0.4.3"
  suffix  = ["tfc", "gwc"]
}

resource "azurerm_resource_group" "main" {
  name     = module.naming.resource_group.name
  location = var.location
}

resource "azurerm_user_assigned_identity" "main" {
  for_each            = local.workspaces
  name                = "${module.naming.user_assigned_identity.name}-${each.key}"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
}

resource "azurerm_federated_identity_credential" "main" {
  for_each = { for pair in setproduct(keys(local.workspaces), tolist(local.run_phases)) :
    "${pair[0]}-${pair[1]}" => {
      workspace = pair[0]
      phase     = pair[1]
    }
  }
  name                = each.key
  resource_group_name = azurerm_user_assigned_identity.main[each.value.workspace].resource_group_name
  parent_id           = azurerm_user_assigned_identity.main[each.value.workspace].id
  audience            = ["api://AzureADTokenExchange"]
  issuer              = "https://app.terraform.io"
  subject             = "organization:${data.tfe_organization.main.name}:project:${data.tfe_project.main.name}:workspace:${each.value.workspace}:run_phase:${each.value.phase}"
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

resource "tfe_variable" "main" {
  for_each = {
    for pair in setproduct(keys(local.workspaces), ["ARM_CLIENT_ID", "TFC_AZURE_RUN_CLIENT_ID"]) :
    "${pair[0]}-${pair[1]}" => {
      workspace_key = pair[0]
      variable_key  = pair[1]
    }
  }
  key          = each.value.variable_key
  value        = azurerm_user_assigned_identity.main[each.value.workspace_key].client_id
  workspace_id = tfe_workspace.main[each.value.workspace_key].id
  category     = "env"
}

module "assignment" {
  source = "./modules/assignment"

  for_each = { for k, v in local.workspaces : k => v if contains(keys(v), "roles") }

  principal_id = azurerm_user_assigned_identity.main[each.key].principal_id
  roles        = each.value.roles
}
