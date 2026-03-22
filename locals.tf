locals {
  # Elastic scale: WS SKUs are always elastic (Azure enforces elasticScaleEnabled=true),
  # EP/P SKUs are user-controllable, others are false.
  # Reference: https://github.com/Azure/terraform-azurerm-avm-res-web-serverfarm/issues/125
  elastic_scale_enabled = local.is_workflow_standard ? true : (can(regex("^(EP|P)", var.sku_name)) ? var.premium_plan_auto_scale_enabled : false)
  # Flex Consumption (FC1) requires special handling for kind, capacity, and maximumElasticWorkerCount
  is_flex_consumption = var.sku_name == "FC1"
  # Workflow Standard (WS1/WS2/WS3) requires kind="elastic" and elasticScaleEnabled=true
  is_workflow_standard = can(regex("^WS", var.sku_name))
  # Determine the kind property based on os_type and sku_name
  # Reference: https://github.com/Azure/app-service-linux-docs/blob/master/Things_You_Should_Know/kind_property.md
  # FC1 (Flex Consumption) always uses "functionapp" regardless of os_type
  # WS (Workflow Standard) always uses "elastic" regardless of os_type
  kind = local.is_flex_consumption ? "functionapp" : (local.is_workflow_standard ? "elastic" : (var.os_type == "Linux" ? "linux" : "windows"))
  # Maximum elastic worker count is applicable to Elastic Premium, WS, and Flex Consumption SKUs
  maximum_elastic_worker_count = can(regex("^(EP|WS|FC)", var.sku_name)) ? var.maximum_elastic_worker_count : var.worker_count
  # FC1 capacity is managed by Azure (always 0), other SKUs use worker_count
  sku_capacity = local.is_flex_consumption ? 0 : var.worker_count
}
