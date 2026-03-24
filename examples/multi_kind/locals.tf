## Section to provide a random Azure region for the resource group
# This allows us to randomize the region for the resource group.
locals {
  plans = {
    linux_standard = {
      os_type        = "Linux"
      sku_name       = "S1"
      worker_count   = 1
      zone_balancing = false
    }
    windows_premium = {
      os_type        = "Windows"
      sku_name       = "P1v2"
      worker_count   = 3
      zone_balancing = true
    }
    flex_consumption = {
      os_type        = "Linux"
      sku_name       = "FC1"
      worker_count   = 0
      zone_balancing = false
    }
    workflow_standard = {
      os_type        = "Windows"
      sku_name       = "WS1"
      worker_count   = 1
      zone_balancing = false
    }
  }
  test_regions = [
    "centralus",
    "southcentralus",
    "canadacentral",
    "eastus",
    "eastus2",
    "westus2",
    "westus3"
  ]
}
