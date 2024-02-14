data "azurerm_resource_group" "parent" {
  count = var.location == null ? 1 : 0

  name = var.resource_group_name
}

resource "azurerm_service_plan" "this" {
  name                = var.name # calling code must supply the name
  resource_group_name = var.resource_group_name
  location            = coalesce(var.location, local.resource_group_location)
  os_type = var.os_type
  sku_name = var.sku_name
  app_service_environment_id = var.app_service_environment_id
  maximum_elastic_worker_count = locals.maximum_elastic_worker_count
  worker_count = var.worker_count
  per_site_scaling_enabled = var.per_site_scaling_enabled
  zone_balancing_enabled = var.zone_balancing_enabled
  tags = var.tags
}

# required AVM resources interfaces
resource "azurerm_management_lock" "this" {
  count = var.lock.kind != "None" ? 1 : 0

  lock_level = var.lock.kind
  name       = coalesce(var.lock.name, "lock-${var.name}")
  scope      = azurerm_service_plan.this.id
}

resource "azurerm_role_assignment" "this" {
  for_each = var.role_assignments

  principal_id                           = each.value.principal_id
  scope                                  = azurerm_service_plan.this.id
  condition                              = each.value.condition
  condition_version                      = each.value.condition_version
  delegated_managed_identity_resource_id = each.value.delegated_managed_identity_resource_id
  role_definition_id                     = strcontains(lower(each.value.role_definition_id_or_name), lower(local.role_definition_resource_substring)) ? each.value.role_definition_id_or_name : null
  role_definition_name                   = strcontains(lower(each.value.role_definition_id_or_name), lower(local.role_definition_resource_substring)) ? null : each.value.role_definition_id_or_name
  skip_service_principal_aad_check       = each.value.skip_service_principal_aad_check
}
