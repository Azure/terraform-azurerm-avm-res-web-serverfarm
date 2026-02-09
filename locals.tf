locals {
  # Elastic scale is only applicable to Elastic Premium and Premium SKUs
  elastic_scale_enabled = can(regex("^(EP|P)", var.sku_name)) ? var.premium_plan_auto_scale_enabled : false
  # Determine the kind property based on os_type and sku_name
  # Reference: https://github.com/Azure/app-service-linux-docs/blob/master/Things_You_Should_Know/kind_property.md
  kind = (
    var.os_type == "Linux" && can(regex("^(EP|Y1|FC|WS)", var.sku_name)) ? "functionapp,linux" :
    var.os_type == "Linux" ? "linux" :
    var.os_type == "WindowsContainer" ? "hyperV" :
    can(regex("^(EP|Y1|FC|WS)", var.sku_name)) ? "functionapp" :
    "app"
  )
  # Maximum elastic worker count is only applicable to Elastic Premium and WS SKUs
  maximum_elastic_worker_count = can(regex("^(EP|WS)", var.sku_name)) ? var.maximum_elastic_worker_count : var.worker_count
}
