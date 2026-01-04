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
    identifier     = "mdmsua/tfc"
    oauth_token_id = "ot-bNRuQwj94Fiuqg27"
  }
}

data "azuread_client_config" "main" {}

resource "azuread_application" "main" {
  for_each = local.workspaces

  display_name = "hcp-terraform-workspace-${each.key}"
  description  = "HCP Terraform workspace ${each.key} of the project ${data.tfe_project.main.name}"
  owners       = [data.azuread_client_config.main.object_id]
}

resource "azuread_service_principal" "main" {
  for_each = local.workspaces

  client_id   = azuread_application.main[each.key].client_id
  description = azuread_application.main[each.key].description
  owners      = [data.azuread_client_config.main.object_id]
}

resource "azuread_application_flexible_federated_identity_credential" "main" {
  for_each = local.workspaces

  application_id             = azuread_application.main[each.key].id
  claims_matching_expression = "claims['sub'] matches 'organization:${data.tfe_organization.main.name}:project:${data.tfe_project.main.name}:workspace:${each.key}:run_phase:*'"
  display_name               = "app.eu.terraform.io-${data.tfe_organization.main.name}-${data.tfe_project.main.name}-${each.key}"
  audience                   = "api://AzureADTokenExchange"
  issuer                     = "https://app.eu.terraform.io"
}

resource "azurerm_role_assignment" "main" {
  for_each = local.workspaces

  principal_id         = azuread_service_principal.main[each.key].object_id
  scope                = "/subscriptions/${data.azurerm_client_config.main.subscription_id}"
  role_definition_name = "Owner"
}

resource "azurerm_resource_provider_registration" "main" {
  for_each = local.resource_providers

  name = each.key

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
  value        = azuread_application.main[each.value.workspace_key].client_id
  workspace_id = tfe_workspace.main[each.value.workspace_key].id
  category     = "env"
}

module "assignment" {
  source = "./modules/assignment"

  for_each = { for k, v in local.workspaces : k => v if contains(keys(v), "roles") }

  principal_id = azuread_service_principal.main[each.key].object_id
  roles        = each.value.roles
}
