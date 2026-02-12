terraform {
  required_version = ">= 1.9, < 2.0"

  required_providers {
    azapi = {
      source  = "Azure/azapi"
      version = "~> 2.4"
    }
    random = {
      source  = "hashicorp/random"
      version = ">= 3.5.0, < 4.0.0"
    }
  }
}

provider "azapi" {}

resource "random_integer" "region_index" {
  max = length(local.test_regions) - 1
  min = 0
}

## End of section to provide a random Azure region for the resource group

# This ensures we have unique CAF compliant names for our resources.
module "naming" {
  source  = "Azure/naming/azurerm"
  version = "0.4.2"
}

# This is required for resource modules
# Hardcoding location due to quota constraints
resource "azapi_resource" "resource_group" {
  location                  = "australiaeast"
  name                      = module.naming.resource_group.name_unique
  type                      = "Microsoft.Resources/resourceGroups@2024-03-01"
  response_export_values    = []
}

# A Log Analytics workspace to send diagnostic logs to
resource "azapi_resource" "log_analytics_workspace" {
  location                  = azapi_resource.resource_group.location
  name                      = module.naming.log_analytics_workspace.name_unique
  parent_id                 = azapi_resource.resource_group.id
  type                      = "Microsoft.OperationalInsights/workspaces@2023-09-01"
  response_export_values    = []
  body = {
    properties = {
      sku = {
        name = "PerGB2018"
      }
      retentionInDays = 30
    }
  }
}

# A user assigned managed identity for role assignment demonstration
resource "azapi_resource" "managed_identity" {
  location                  = azapi_resource.resource_group.location
  name                      = module.naming.user_assigned_identity.name_unique
  parent_id                 = azapi_resource.resource_group.id
  type                      = "Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31"
  response_export_values    = ["properties.principalId"]
}

# This is the module call
module "test" {
  source = "../.."

  location  = azapi_resource.resource_group.location
  name      = module.naming.app_service_plan.name_unique
  os_type   = "Linux"
  parent_id = azapi_resource.resource_group.id
  # Diagnostic settings - sends metrics to Log Analytics workspace
  diagnostic_settings = {
    to_law = {
      name                  = "diag-to-law"
      workspace_resource_id = azapi_resource.log_analytics_workspace.id
      metrics = [
        {
          category = "AllMetrics"
          enabled  = true
        }
      ]
    }
  }
  enable_telemetry = var.enable_telemetry
  # Management lock - prevents accidental deletion
  lock = {
    kind = "CanNotDelete"
    name = "lock-asp-complete"
  }
  # Managed identities
  managed_identities = {
    system_assigned            = true
    user_assigned_resource_ids = [azapi_resource.managed_identity.id]
  }
  # Role assignments - grant the managed identity Reader access
  role_assignments = {
    reader = {
      role_definition_id_or_name = "Reader"
      principal_id               = azapi_resource.managed_identity.output.properties.principalId
      principal_type             = "ServicePrincipal"
    }
  }
  # Tags
  tags = {
    environment = "complete-example"
  }
}
