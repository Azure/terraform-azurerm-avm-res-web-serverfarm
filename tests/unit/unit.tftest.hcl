# Unit tests for the App Service Plan (serverfarm) module.
#
# These tests focus on the FC1 (Flex Consumption) zone-redundancy region precondition added for
# https://github.com/Azure/terraform-azurerm-avm-res-web-serverfarm/issues/133. The geoRegions
# data source is mocked so the precondition can be exercised without calling Azure.

mock_provider "azapi" {
  mock_data "azapi_client_config" {
    defaults = {
      subscription_id          = "00000000-0000-0000-0000-000000000000"
      tenant_id                = "00000000-0000-0000-0000-000000000001"
      subscription_resource_id = "/subscriptions/00000000-0000-0000-0000-000000000000"
    }
  }

  # geoRegions response: East US 2 supports zone-redundant Flex Consumption (FCZONEREDUNDANCY),
  # West US offers Flex Consumption but NOT zone redundancy.
  mock_data "azapi_resource_action" {
    defaults = {
      output = {
        value = [
          {
            properties = {
              name      = "East US 2"
              orgDomain = "PUBLIC;FLEXCONSUMPTION;FCZONEREDUNDANCY"
            }
          },
          {
            properties = {
              name      = "West US"
              orgDomain = "PUBLIC;FLEXCONSUMPTION"
            }
          },
        ]
      }
    }
  }
}

mock_provider "random" {}

variables {
  name      = "asp-unit-test"
  parent_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-unit-test"
  os_type   = "Linux"
}

# Non-Flex SKUs must not trigger the geoRegions lookup and must deploy regardless of region.
run "non_flex_skips_region_lookup" {
  command = apply

  variables {
    location               = "westus"
    sku_name               = "P1v2"
    zone_balancing_enabled = true
  }

  assert {
    condition     = length(data.azapi_resource_action.flex_consumption_geo_regions) == 0
    error_message = "The geoRegions data source must not be evaluated for non-Flex Consumption SKUs."
  }

  assert {
    condition     = can(azapi_resource.this)
    error_message = "The App Service Plan should be created for a standard SKU."
  }

  assert {
    condition     = azapi_resource.this.body.sku.capacity == 3
    error_message = "The App Service Plan should manage SKU capacity by default."
  }

  assert {
    condition     = !contains(keys(azapi_resource.this.body.properties), "asyncScalingEnabled")
    error_message = "Async scaling must be omitted when async_scaling_enabled is unset."
  }
  providers = {
    azapi  = azapi
    random = random
  }
}

run "async_scaling_enabled" {
  command = apply

  variables {
    async_scaling_enabled  = true
    location               = "westus"
    sku_name               = "P1v2"
    zone_balancing_enabled = false
  }

  assert {
    condition     = azapi_resource.this.body.properties.asyncScalingEnabled == true
    error_message = "Async scaling must be enabled in the App Service Plan request body."
  }
  providers = {
    azapi  = azapi
    random = random
  }
}

# worker_count = null supports external autoscale by omitting capacity fields that Azure Monitor owns.
run "worker_count_null_omits_capacity" {
  command = apply

  variables {
    location               = "westus"
    sku_name               = "S1"
    worker_count           = null
    zone_balancing_enabled = false
  }

  assert {
    condition     = !contains(keys(azapi_resource.this.body.sku), "capacity")
    error_message = "SKU capacity must be omitted when worker_count is null."
  }

  assert {
    condition     = !contains(keys(azapi_resource.this.body.properties), "maximumElasticWorkerCount")
    error_message = "maximumElasticWorkerCount must be omitted when worker_count is null for non-elastic SKUs."
  }
  providers = {
    azapi  = azapi
    random = random
  }
}

# FC1 + zone balancing in a supported region must pass the precondition and create the plan.
run "flex_zone_supported_region" {
  command = apply

  variables {
    location               = "East US 2"
    sku_name               = "FC1"
    zone_balancing_enabled = true
  }

  assert {
    condition     = length(data.azapi_resource_action.flex_consumption_geo_regions) == 1
    error_message = "The geoRegions data source must be evaluated when FC1 + zone balancing is requested."
  }

  assert {
    condition     = contains(local.flex_consumption_zone_redundant_locations, "eastus2")
    error_message = "East US 2 should be detected as a zone-redundant Flex Consumption region."
  }

  assert {
    condition     = can(azapi_resource.this)
    error_message = "The FC1 plan should be created in a supported zone-redundant region."
  }
  providers = {
    azapi  = azapi
    random = random
  }
}

# FC1 + zone balancing disabled must skip the region lookup and deploy in any region.
run "flex_zone_disabled_any_region" {
  command = apply

  variables {
    location               = "westus"
    sku_name               = "FC1"
    zone_balancing_enabled = false
  }

  assert {
    condition     = length(data.azapi_resource_action.flex_consumption_geo_regions) == 0
    error_message = "The geoRegions data source must not be evaluated when zone balancing is disabled."
  }

  assert {
    condition     = can(azapi_resource.this)
    error_message = "FC1 without zone balancing should deploy in any region."
  }
  providers = {
    azapi  = azapi
    random = random
  }
}

# FC1 + zone balancing in an unsupported region must fail the precondition.
# Uses command = plan because the precondition is evaluated during planning.
run "flex_zone_unsupported_region" {
  command = plan

  variables {
    location               = "West US"
    sku_name               = "FC1"
    zone_balancing_enabled = true
  }

  expect_failures = [
    azapi_resource.this,
  ]
  providers = {
    azapi  = azapi
    random = random
  }
}

# Premium (P*) automatic scaling: maximum_elastic_worker_count sets the maximum burst above the baseline worker_count.
run "premium_auto_scale_maximum_burst_above_worker_count" {
  command = apply

  variables {
    location                        = "westus"
    maximum_elastic_worker_count    = 8
    premium_plan_auto_scale_enabled = true
    sku_name                        = "P2v3"
    worker_count                    = 2
    zone_balancing_enabled          = false
  }

  assert {
    condition     = azapi_resource.this.body.properties.elasticScaleEnabled == true
    error_message = "Automatic scaling must be enabled for a Premium SKU when premium_plan_auto_scale_enabled is true."
  }

  assert {
    condition     = azapi_resource.this.body.sku.capacity == 2
    error_message = "SKU capacity must equal worker_count."
  }

  assert {
    condition     = azapi_resource.this.body.properties.maximumElasticWorkerCount == 8
    error_message = "maximumElasticWorkerCount must equal maximum_elastic_worker_count for a Premium SKU with automatic scaling."
  }
  providers = {
    azapi  = azapi
    random = random
  }
}

# Premium (P*) automatic scaling without maximum_elastic_worker_count keeps the maximum burst at worker_count.
run "premium_auto_scale_maximum_burst_defaults_to_worker_count" {
  command = apply

  variables {
    location                        = "westus"
    premium_plan_auto_scale_enabled = true
    sku_name                        = "P2v3"
    worker_count                    = 2
    zone_balancing_enabled          = false
  }

  assert {
    condition     = azapi_resource.this.body.properties.maximumElasticWorkerCount == 2
    error_message = "maximumElasticWorkerCount must equal worker_count when maximum_elastic_worker_count is unset."
  }
  providers = {
    azapi  = azapi
    random = random
  }
}

# Premium (P*) without automatic scaling ignores maximum_elastic_worker_count.
run "premium_without_auto_scale_ignores_maximum_elastic_worker_count" {
  command = apply

  variables {
    location                     = "westus"
    maximum_elastic_worker_count = 8
    sku_name                     = "P2v3"
    worker_count                 = 2
    zone_balancing_enabled       = false
  }

  assert {
    condition     = azapi_resource.this.body.properties.maximumElasticWorkerCount == 2
    error_message = "maximumElasticWorkerCount must equal worker_count when automatic scaling is disabled."
  }
  providers = {
    azapi  = azapi
    random = random
  }
}

# Premium (P*) automatic scaling rejects a maximum burst below worker_count.
run "premium_auto_scale_maximum_burst_below_worker_count_fails" {
  command = plan

  variables {
    location                        = "westus"
    maximum_elastic_worker_count    = 2
    premium_plan_auto_scale_enabled = true
    sku_name                        = "P2v3"
    worker_count                    = 4
    zone_balancing_enabled          = false
  }

  expect_failures = [
    var.maximum_elastic_worker_count,
  ]
  providers = {
    azapi  = azapi
    random = random
  }
}

# Elastic Premium (EP*) keeps a maximum of 3 when maximum_elastic_worker_count is unset.
run "elastic_premium_maximum_defaults_to_three" {
  command = apply

  variables {
    location               = "westus"
    sku_name               = "EP1"
    worker_count           = 1
    zone_balancing_enabled = false
  }

  assert {
    condition     = azapi_resource.this.body.properties.maximumElasticWorkerCount == 3
    error_message = "maximumElasticWorkerCount must default to 3 for Elastic Premium SKUs."
  }
  providers = {
    azapi  = azapi
    random = random
  }
}
