locals {
  maximum_elastic_worker_count       = can(regex("E1|E2|E3", var.sku_name)) ? var.maximum_elastic_worker_count : null
  resource_group_location            = try(data.azurerm_resource_group.parent[0].location, null)
  role_definition_resource_substring = "/providers/Microsoft.Authorization/roleDefinitions"
}

# Private endpoint application security group associations
# Remove if this resource does not support private endpoints
locals {
}
