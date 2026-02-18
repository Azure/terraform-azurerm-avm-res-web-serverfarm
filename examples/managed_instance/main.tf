terraform {
  required_version = ">= 1.9, < 2.0"

  required_providers {
    archive = {
      source  = "hashicorp/archive"
      version = "~> 2.7"
    }
    azapi = {
      source  = "Azure/azapi"
      version = "~> 2.4"
    }
    azurerm = {
      source  = "hashicorp/azurerm"
      version = ">= 3.0, < 5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = ">= 3.5.0, < 4.0.0"
    }
  }
}

provider "azapi" {}

provider "azurerm" {
  features {
    key_vault {
      purge_soft_delete_on_destroy          = false
      purge_soft_deleted_keys_on_destroy    = false
      purge_soft_deleted_secrets_on_destroy = false
    }
  }
  storage_use_azuread = true
}

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
  location               = "australiaeast"
  name                   = module.naming.resource_group.name_unique
  type                   = "Microsoft.Resources/resourceGroups@2024-03-01"
  response_export_values = []
  tags = {
    SecurityControl = "Ignore" # Useful for test environments
  }
}

# A user assigned managed identity for the Managed Instance plan default identity
resource "azapi_resource" "managed_identity" {
  location               = azapi_resource.resource_group.location
  name                   = module.naming.user_assigned_identity.name_unique
  parent_id              = azapi_resource.resource_group.id
  type                   = "Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31"
  response_export_values = ["properties.principalId"]
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
      name = "Standard_ZRS"
    }
  }
  response_export_values = []
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
  response_export_values = []
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
  response_export_values = []

  depends_on = [azapi_resource.blob_container]
}

data "azapi_client_config" "this" {}

# Virtual network for the Managed Instance App Service Plan
resource "azapi_resource" "virtual_network" {
  location  = azapi_resource.resource_group.location
  name      = module.naming.virtual_network.name_unique
  parent_id = azapi_resource.resource_group.id
  type      = "Microsoft.Network/virtualNetworks@2024-05-01"
  body = {
    properties = {
      addressSpace = {
        addressPrefixes = ["10.0.0.0/16"]
      }
    }
  }
  response_export_values = []
}

# Subnet for the App Service Plan delegation
resource "azapi_resource" "subnet" {
  name      = "default"
  parent_id = azapi_resource.virtual_network.id
  type      = "Microsoft.Network/virtualNetworks/subnets@2024-05-01"
  body = {
    properties = {
      addressPrefix = "10.0.0.0/24"
      delegations = [
        {
          name = "Microsoft.Web.serverFarms"
          properties = {
            serviceName = "Microsoft.Web/serverFarms"
          }
        }
      ]
    }
  }
  response_export_values = []
}

# Subnet for Azure Bastion
resource "azapi_resource" "bastion_subnet" {
  name      = "AzureBastionSubnet"
  parent_id = azapi_resource.virtual_network.id
  type      = "Microsoft.Network/virtualNetworks/subnets@2024-05-01"
  body = {
    properties = {
      addressPrefix = "10.0.1.0/26"
    }
  }
  response_export_values = []

  depends_on = [azapi_resource.subnet]
}

# Public IP for Azure Bastion
resource "azapi_resource" "bastion_public_ip" {
  location  = azapi_resource.resource_group.location
  name      = "${module.naming.public_ip.name_unique}-bastion"
  parent_id = azapi_resource.resource_group.id
  type      = "Microsoft.Network/publicIPAddresses@2024-05-01"
  body = {
    properties = {
      publicIPAllocationMethod = "Static"
      publicIPAddressVersion   = "IPv4"
    }
    sku = {
      name = "Standard"
    }
    zones = ["1", "2", "3"]
  }
  response_export_values = []
}

# Azure Bastion Host with Standard SKU
resource "azapi_resource" "bastion_host" {
  location  = azapi_resource.resource_group.location
  name      = module.naming.bastion_host.name_unique
  parent_id = azapi_resource.resource_group.id
  type      = "Microsoft.Network/bastionHosts@2024-05-01"
  body = {
    properties = {
      ipConfigurations = [
        {
          name = "bastion-ip-config"
          properties = {
            publicIPAddress = {
              id = azapi_resource.bastion_public_ip.id
            }
            subnet = {
              id = azapi_resource.bastion_subnet.id
            }
          }
        }
      ]
      scaleUnits = 2
    }
    sku = {
      name = "Standard"
    }
    zones = ["1", "2", "3"]
  }
  response_export_values = []

  timeouts {
    create = "60m"
    delete = "60m"
  }
}

# File share for H: drive mount
resource "azapi_resource" "file_share" {
  name      = "hshare"
  parent_id = "${azapi_resource.storage_account.id}/fileServices/default"
  type      = "Microsoft.Storage/storageAccounts/fileServices/shares@2023-05-01"
  body = {
    properties = {
      shareQuota = 5
    }
  }
  response_export_values = []
}

# Key Vault for storing the storage account key
resource "azapi_resource" "key_vault" {
  location  = azapi_resource.resource_group.location
  name      = module.naming.key_vault.name_unique
  parent_id = azapi_resource.resource_group.id
  type      = "Microsoft.KeyVault/vaults@2023-07-01"
  body = {
    properties = {
      enablePurgeProtection        = null
      enableRbacAuthorization      = true
      enableSoftDelete             = false
      enabledForDeployment         = false
      enabledForTemplateDeployment = false
      sku = {
        family = "A"
        name   = "standard"
      }
      tenantId = data.azapi_client_config.this.tenant_id
    }
  }
  response_export_values = []
}

# Grant the current user "Key Vault Secrets Officer" so we can create the secret
resource "azapi_resource" "role_assignment_kv_secrets_officer" {
  name      = "b1c2d3e4-f5a6-7890-abcd-ef1234567891"
  parent_id = azapi_resource.key_vault.id
  type      = "Microsoft.Authorization/roleAssignments@2022-04-01"
  body = {
    properties = {
      principalId      = data.azapi_client_config.this.object_id
      roleDefinitionId = "/subscriptions/${data.azapi_client_config.this.subscription_id}/providers/Microsoft.Authorization/roleDefinitions/b86a8fe4-44ce-4948-aee5-eccb2c155cd7"
    }
  }
  response_export_values = []
}

# Grant the managed identity "Key Vault Secrets User" on the Key Vault
# so the App Service Plan can read secrets for registry adapters and storage mount credentials
resource "azapi_resource" "role_assignment_kv_secrets_user" {
  name      = "c2d3e4f5-a6b7-8901-bcde-f12345678902"
  parent_id = azapi_resource.key_vault.id
  type      = "Microsoft.Authorization/roleAssignments@2022-04-01"
  body = {
    properties = {
      principalId      = azapi_resource.managed_identity.output.properties.principalId
      principalType    = "ServicePrincipal"
      roleDefinitionId = "/subscriptions/${data.azapi_client_config.this.subscription_id}/providers/Microsoft.Authorization/roleDefinitions/4633458b-17de-408a-b874-0445c86b69e6"
    }
  }
  response_export_values = []
}

# Retrieve the storage account keys
data "azapi_resource_action" "storage_account_keys" {
  action                 = "listKeys"
  resource_id            = azapi_resource.storage_account.id
  type                   = "Microsoft.Storage/storageAccounts@2023-05-01"
  response_export_values = ["keys"]
}

# Store the storage account connection string in Key Vault as a secret
resource "azurerm_key_vault_secret" "storage_key" {
  key_vault_id = azapi_resource.key_vault.id
  name         = "storage-account-key"
  value        = "DefaultEndpointsProtocol=https;AccountName=${azapi_resource.storage_account.name};AccountKey=${data.azapi_resource_action.storage_account_keys.output.keys[0].value};EndpointSuffix=core.windows.net"

  depends_on = [azapi_resource.role_assignment_kv_secrets_officer]
}

# Key Vault secret for a registry adapter string value
resource "azurerm_key_vault_secret" "registry_string" {
  key_vault_id = azapi_resource.key_vault.id
  name         = "registry-string-value"
  value        = "MyExampleStringValue"

  depends_on = [azapi_resource.role_assignment_kv_secrets_officer]
}

# Key Vault secret for a registry adapter DWORD value
resource "azurerm_key_vault_secret" "registry_dword" {
  key_vault_id = azapi_resource.key_vault.id
  name         = "registry-dword-value"
  value        = "336" # Must be an Integer

  depends_on = [azapi_resource.role_assignment_kv_secrets_officer]
}

data "archive_file" "scripts" {
  type             = "zip"
  source_dir       = "${path.module}/scripts"
  output_path      = "${path.module}/scripts.zip"
  output_file_mode = "0644"
}

# Upload scripts.zip as a placeholder for the install script package.
resource "azurerm_storage_blob" "scripts_zip" {
  name                   = "scripts.zip"
  storage_account_name   = azapi_resource.storage_account.name
  storage_container_name = azapi_resource.blob_container.name
  type                   = "Block"
  content_md5            = data.archive_file.scripts.output_md5
  source                 = data.archive_file.scripts.output_path

  depends_on = [azapi_resource.role_assignment_blob_reader, azapi_resource.role_assignment_blob_contributor_current_user]
}

# Grant the current user "Storage Blob Data Contributor" on the storage account
# so the azurerm provider can upload the blob via Azure AD auth
resource "azapi_resource" "role_assignment_blob_contributor_current_user" {
  name      = "a1b2c3d4-e5f6-7890-abcd-ef1234567890"
  parent_id = azapi_resource.storage_account.id
  type      = "Microsoft.Authorization/roleAssignments@2022-04-01"
  body = {
    properties = {
      principalId      = data.azapi_client_config.this.object_id
      roleDefinitionId = "/subscriptions/${data.azapi_client_config.this.subscription_id}/providers/Microsoft.Authorization/roleDefinitions/ba92f5b4-2d11-453d-a403-e96b0029c9fe"
    }
  }
  response_export_values = []

  depends_on = [azapi_resource.blob_container]
}

# This is the module call to create the App Service Managed Instance plan with custom configuration using install scripts, registry adapters, and storage mounts.
module "test" {
  source = "../.."

  location         = azapi_resource.resource_group.location
  name             = module.naming.app_service_plan.name_unique
  os_type          = "WindowsManagedInstance"
  parent_id        = azapi_resource.resource_group.id
  enable_telemetry = var.enable_telemetry
  # Install scripts - references the scripts.zip blob in the storage account
  # The install script logs can be found in C:\InstallScripts on the VM instances
  install_scripts = [
    {
      name = "CustomInstaller"
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
  rdp_enabled = true
  # Registry adapters - configure Windows registry keys via Key Vault references
  registry_adapters = [
    {
      registry_key = "HKEY_LOCAL_MACHINE/SOFTWARE/MyApp1/RegistryAdapterString" # Registry key must start with HKEY_LOCAL_MACHINE, HKEY_CURRENT_USER, or HKEY_USERS and contain at least one forward slash.
      type         = "String"
      key_vault_secret_reference = {
        secret_uri = "https://${azapi_resource.key_vault.name}.vault.azure.net/secrets/${azurerm_key_vault_secret.registry_string.name}"
      }
    },
    {
      registry_key = "HKEY_LOCAL_MACHINE/SOFTWARE/MyApp1/RegistryAdapterDWORD" # Registry key must start with HKEY_LOCAL_MACHINE, HKEY_CURRENT_USER, or HKEY_USERS and contain at least one forward slash.
      type         = "DWORD"
      key_vault_secret_reference = {
        secret_uri = "https://${azapi_resource.key_vault.name}.vault.azure.net/secrets/${azurerm_key_vault_secret.registry_dword.name}"
      }
    }
  ]
  sku_name = "P1v4" # V4 skus are required for Windows Managed Instance
  # Storage mount for G: drive
  storage_mounts = [
    {
      name             = "g-drive"
      type             = "LocalStorage"
      destination_path = "G:\\"
    },
    {
      name             = "h-drive"
      type             = "AzureFiles"
      source           = "\\\\${azapi_resource.storage_account.name}.file.core.windows.net\\${azapi_resource.file_share.name}"
      destination_path = "H:\\"
      credentials_key_vault_reference = {
        secret_uri = "https://${azapi_resource.key_vault.name}.vault.azure.net//secrets/${azurerm_key_vault_secret.storage_key.name}" # NOTE: the double slash after the vault URI is intentional to comply with Key Vault secret URI format for this resource
      }
    }
  ]
  virtual_network_subnet_id = azapi_resource.subnet.id
  worker_count              = 3

  depends_on = [azurerm_storage_blob.scripts_zip]
}

# Web App running .NET 10 on Windows, hosted on the Managed Instance plan
resource "azapi_resource" "web_app" {
  location  = azapi_resource.resource_group.location
  name      = module.naming.app_service.name_unique
  parent_id = azapi_resource.resource_group.id
  type      = "Microsoft.Web/sites@2024-04-01"
  body = {
    kind = "app"
    properties = {
      serverFarmId = module.test.resource_id
      siteConfig = {
        alwaysOn            = true # NOTE: If the web app is not deployed and running, you will not be able to RDP onto the instances
        netFrameworkVersion = "v10.0"
        metadata = [
          {
            name  = "CURRENT_STACK"
            value = "dotnet"
          }
        ]
      }
    }
  }
  response_export_values    = []
  schema_validation_enabled = false
}
