# AVM Interfaces module for locks, role assignments, diagnostic settings, and managed identities
module "avm_interfaces" {
  source  = "Azure/avm-utl-interfaces/azure"
  version = "0.5.0"

  diagnostic_settings                       = var.diagnostic_settings
  enable_telemetry                          = var.enable_telemetry
  lock                                      = var.lock
  managed_identities                        = var.managed_identities
  role_assignment_definition_lookup_enabled = true
  role_assignment_definition_scope          = "/subscriptions/${data.azapi_client_config.this.subscription_id}"
  role_assignments                          = var.role_assignments
}

resource "azapi_resource" "this" {
  location  = var.location
  name      = var.name
  parent_id = var.parent_id
  type      = "Microsoft.Web/serverfarms@2025-03-01"
  body = {
    kind = local.kind
    properties = {
      asyncScalingEnabled       = null
      freeOfferExpirationTime   = null
      isCustomMode              = null
      isSpot                    = null
      isXenon                   = null
      kubeEnvironmentProfile    = null
      elasticScaleEnabled       = local.elastic_scale_enabled
      hostingEnvironmentProfile = var.app_service_environment_id != null ? { id = var.app_service_environment_id } : null
      hyperV                    = var.os_type == "WindowsContainer"
      maximumElasticWorkerCount = local.maximum_elastic_worker_count
      perSiteScaling            = var.per_site_scaling_enabled
      spotExpirationTime        = null
      reserved                  = var.os_type == "Linux"
      targetWorkerCount         = null
      targetWorkerSizeId        = null
      workerTierName            = null
      zoneRedundant             = var.zone_balancing_enabled
    }
    sku = {
      name     = var.sku_name
      capacity = var.worker_count
      family   = null
      size     = null
      tier     = null
    }
  }
  create_headers            = var.enable_telemetry ? { "User-Agent" : local.avm_azapi_header } : null
  delete_headers            = var.enable_telemetry ? { "User-Agent" : local.avm_azapi_header } : null
  read_headers              = var.enable_telemetry ? { "User-Agent" : local.avm_azapi_header } : null
  schema_validation_enabled = false
  tags                      = var.tags
  update_headers            = var.enable_telemetry ? { "User-Agent" : local.avm_azapi_header } : null

  dynamic "identity" {
    for_each = module.avm_interfaces.managed_identities_azapi != null ? { this = module.avm_interfaces.managed_identities_azapi } : {}

    content {
      type         = identity.value.type
      identity_ids = identity.value.identity_ids
    }
  }

  lifecycle {
    ignore_changes = [
      body.properties.asyncScalingEnabled,
      body.properties.freeOfferExpirationTime,
      body.properties.isCustomMode,
      body.properties.isSpot,
      body.properties.isXenon,
      body.properties.kubeEnvironmentProfile,
      body.properties.spotExpirationTime,
      body.properties.targetWorkerCount,
      body.properties.targetWorkerSizeId,
      body.properties.workerTierName,
      body.sku.family,
      body.sku.size,
      body.sku.tier
    ]
  }
}

moved {
  from = azurerm_service_plan.this
  to   = azapi_resource.this
}

moved {
  from = azurerm_management_lock.this
  to   = azapi_resource.lock
}

moved {
  from = azurerm_role_assignment.this
  to   = azapi_resource.role_assignment
}

data "azapi_client_config" "this" {}

# Lock
resource "azapi_resource" "lock" {
  count = var.lock != null ? 1 : 0

  name           = module.avm_interfaces.lock_azapi.name
  parent_id      = azapi_resource.this.id
  type           = module.avm_interfaces.lock_azapi.type
  body           = module.avm_interfaces.lock_azapi.body
  create_headers = var.enable_telemetry ? { "User-Agent" : local.avm_azapi_header } : null
  delete_headers = var.enable_telemetry ? { "User-Agent" : local.avm_azapi_header } : null
  read_headers   = var.enable_telemetry ? { "User-Agent" : local.avm_azapi_header } : null
  update_headers = var.enable_telemetry ? { "User-Agent" : local.avm_azapi_header } : null
}

# Role Assignments
resource "azapi_resource" "role_assignment" {
  for_each = module.avm_interfaces.role_assignments_azapi

  name           = each.value.name
  parent_id      = azapi_resource.this.id
  type           = each.value.type
  body           = each.value.body
  create_headers = var.enable_telemetry ? { "User-Agent" : local.avm_azapi_header } : null
  delete_headers = var.enable_telemetry ? { "User-Agent" : local.avm_azapi_header } : null
  read_headers   = var.enable_telemetry ? { "User-Agent" : local.avm_azapi_header } : null
  update_headers = var.enable_telemetry ? { "User-Agent" : local.avm_azapi_header } : null
}

# Diagnostic Settings
resource "azapi_resource" "diagnostic_setting" {
  for_each = module.avm_interfaces.diagnostic_settings_azapi

  name           = each.value.name
  parent_id      = azapi_resource.this.id
  type           = each.value.type
  body           = each.value.body
  create_headers = var.enable_telemetry ? { "User-Agent" : local.avm_azapi_header } : null
  delete_headers = var.enable_telemetry ? { "User-Agent" : local.avm_azapi_header } : null
  read_headers   = var.enable_telemetry ? { "User-Agent" : local.avm_azapi_header } : null
  update_headers = var.enable_telemetry ? { "User-Agent" : local.avm_azapi_header } : null
}
