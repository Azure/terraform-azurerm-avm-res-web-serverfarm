locals {
  # Elastic scale is only applicable to Elastic Premium and Premium SKUs
  elastic_scale_enabled = can(regex("^(EP|P)", var.sku_name)) ? var.premium_plan_auto_scale_enabled : false
  # Flex Consumption (FC1) requires special handling for kind, capacity, and maximumElasticWorkerCount
  is_flex_consumption = var.sku_name == "FC1"
  # Determine the kind property based on os_type and sku_name
  # Reference: https://github.com/Azure/app-service-linux-docs/blob/master/Things_You_Should_Know/kind_property.md
  # FC1 (Flex Consumption) always uses "functionapp" regardless of os_type
  kind = local.is_flex_consumption ? "functionapp" : (var.os_type == "Linux" ? "linux" : "windows")
  # Maximum elastic worker count is applicable to Elastic Premium, WS, and Flex Consumption SKUs
  maximum_elastic_worker_count = can(regex("^(EP|WS|FC)", var.sku_name)) ? var.maximum_elastic_worker_count : var.worker_count
  # FC1 capacity is managed by Azure (always 0), other SKUs use worker_count
  sku_capacity = local.is_flex_consumption ? 0 : var.worker_count
}
