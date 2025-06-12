locals {
  maximum_elastic_worker_count       = can(regex("EP1|EP2|EP3", var.sku_name)) ? var.maximum_elastic_worker_count : null
  role_definition_resource_substring = "/providers/Microsoft.Authorization/roleDefinitions"
  worker_count = (
    var.sku_name == "Y1" ? 0 :
    var.zone_balancing_enabled ?
    ceil(var.worker_count / length(data.azurerm_location.region.zone_mappings)) * length(data.azurerm_location.region.zone_mappings) :
    var.worker_count
  )
}
