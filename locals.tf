locals {
  maximum_elastic_worker_count       = can(regex("E1|E2|E3", var.sku_name)) ? var.maximum_elastic_worker_count : null
  role_definition_resource_substring = "/providers/Microsoft.Authorization/roleDefinitions"
}
