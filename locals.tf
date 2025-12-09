locals {
  maximum_elastic_worker_count       = can(regex("EP1|EP2|EP3|WS1|WS2|WS3", var.sku_name)) ? var.maximum_elastic_worker_count : null
  role_definition_resource_substring = "/providers/Microsoft.Authorization/roleDefinitions"
  worker_count = (
    can(regex("Y1|FC1", var.sku_name)) ? 0 :
    var.zone_balancing_enabled ?
    ceil(var.worker_count / length(data.azurerm_location.region.zone_mappings)) * length(data.azurerm_location.region.zone_mappings) :
    var.worker_count
  )
}
