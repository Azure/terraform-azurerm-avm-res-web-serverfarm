# Unit tests for the App Service Plan (serverfarm) module.
#
# These tests focus on the FC1 (Flex Consumption) zone-redundancy region precondition added for
# https://github.com/Azure/terraform-azurerm-avm-res-web-serverfarm/issues/133. The geoRegions
# data source is mocked so the precondition can be exercised without calling Azure.

mock_provider "azapi" {
  mock_data "azapi_client_config" {
    defaults = {
      subscription_id = "00000000-0000-0000-0000-000000000000"
      tenant_id       = "00000000-0000-0000-0000-000000000001"
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
mock_provider "modtm" {}
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
}
