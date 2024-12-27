locals {
  maximum_elastic_worker_count       = can(regex("EP1|EP2|EP3", var.sku_name)) ? var.maximum_elastic_worker_count : null
  role_definition_resource_substring = "/providers/Microsoft.Authorization/roleDefinitions"
}
