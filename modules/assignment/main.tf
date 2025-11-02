data "azuread_application_published_app_ids" "main" {}

resource "azuread_service_principal" "main" {
  for_each = var.roles

  client_id    = data.azuread_application_published_app_ids.main.result[each.key]
  use_existing = true
}

data "azuread_service_principal" "main" {
  object_id = var.principal_id
}

resource "azuread_app_role_assignment" "main" {
  for_each = toset([for k, v in var.roles : [for r in v : "${k}/${r}"]]...)

  app_role_id         = azuread_service_principal.main[split("/", each.key)[0]].app_role_ids[split("/", each.key)[1]]
  principal_object_id = data.azuread_service_principal.main.object_id
  resource_object_id  = azuread_service_principal.main[split("/", each.key)[0]].object_id
}
