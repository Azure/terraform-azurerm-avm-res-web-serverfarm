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
  location = "australiaeast"
  name     = module.naming.resource_group.name_unique
  type     = "Microsoft.Resources/resourceGroups@2024-03-01"
}

# A user assigned managed identity for the Managed Instance plan default identity
resource "azapi_resource" "managed_identity" {
  location  = azapi_resource.resource_group.location
  name      = module.naming.user_assigned_identity.name_unique
  parent_id = azapi_resource.resource_group.id
  type      = "Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31"
}

# Storage account to host the install scripts package
resource "azapi_resource" "storage_account" {
  location  = azapi_resource.resource_group.location
  name      = module.naming.storage_account.name_unique
  parent_id = azapi_resource.resource_group.id
  type      = "Microsoft.Storage/storageAccounts@2023-05-01"
  body = {
    kind = "StorageV2"
    properties = {
      accessTier               = "Hot"
      allowBlobPublicAccess    = false
      allowSharedKeyAccess     = true
      minimumTlsVersion        = "TLS1_2"
      supportsHttpsTrafficOnly = true
      publicNetworkAccess      = "Enabled"
      networkAcls = {
        defaultAction = "Allow"
      }
    }
    sku = {
      name = "Standard_LRS"
    }
  }
}

# Blob container to hold scripts.zip
resource "azapi_resource" "blob_container" {
  name      = "scripts"
  parent_id = "${azapi_resource.storage_account.id}/blobServices/default"
  type      = "Microsoft.Storage/storageAccounts/blobServices/containers@2023-05-01"
  body = {
    properties = {
      publicAccess = "None"
    }
  }
}

# Grant the managed identity "Storage Blob Data Reader" on the storage account
# so the plan can pull install scripts
resource "azapi_resource" "role_assignment_blob_reader" {
  name      = "7d2b4b60-b4a1-4e5e-a123-abcdef012345"
  parent_id = azapi_resource.storage_account.id
  type      = "Microsoft.Authorization/roleAssignments@2022-04-01"
  body = {
    properties = {
      principalId      = azapi_resource.managed_identity.output.properties.principalId
      principalType    = "ServicePrincipal"
      roleDefinitionId = "/subscriptions/${data.azapi_client_config.this.subscription_id}/providers/Microsoft.Authorization/roleDefinitions/2a2b9908-6ea1-4ae2-8e65-a410df84e7d1"
    }
  }

  depends_on = [azapi_resource.blob_container]
}

data "azapi_client_config" "this" {}

# Upload scripts.zip as a placeholder for the install script package.
# Replace the source with your own scripts.zip file.
resource "terraform_data" "scripts_zip_upload" {
  input = "${path.module}/scripts.zip"

  provisioner "local-exec" {
    command = "az storage blob upload --account-name ${azapi_resource.storage_account.name} --container-name ${azapi_resource.blob_container.name} --name scripts.zip --file \"${path.module}/scripts.zip\" --auth-mode login --overwrite"
  }

  depends_on = [azapi_resource.role_assignment_blob_reader]
}

# This is the module call
# Windows Managed Instance uses isCustomMode, install scripts, and plan default identity
module "test" {
  source = "../.."

  location         = azapi_resource.resource_group.location
  name             = module.naming.app_service_plan.name_unique
  os_type          = "WindowsManagedInstance"
  parent_id        = azapi_resource.resource_group.id
  enable_telemetry = var.enable_telemetry
  # Install scripts - references the scripts.zip blob in the storage account
  install_scripts = [
    {
      name = "FontInstaller"
      source = {
        type       = "RemoteAzureBlob"
        source_uri = "https://${azapi_resource.storage_account.name}.blob.core.windows.net/${azapi_resource.blob_container.name}/scripts.zip"
      }
    }
  ]
  # Managed identities - the user-assigned identity must be attached to the plan
  managed_identities = {
    user_assigned_resource_ids = [azapi_resource.managed_identity.id]
  }
  # Plan default identity - used by the platform to pull install scripts
  plan_default_identity = {
    identity_type                      = "UserAssigned"
    user_assigned_identity_resource_id = azapi_resource.managed_identity.id
  }
  sku_name     = "P1v3"
  worker_count = 1
}
