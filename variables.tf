variable "location" {
  type        = string
  description = "The location where the resources will be deployed."
  nullable    = false
}

variable "name" {
  type        = string
  description = "The name of the this resource."

  validation {
    condition     = can(regex("^[a-zA-Z0-9-_]{1,60}$", var.name))
    error_message = "The name must be between 1 and 60 characters long and can only contain letters, numbers, hyphens, underscores and Unicode characters."
  }
}

variable "os_type" {
  type        = string
  description = "The operating system type of the service plan. Possible values are `Windows`, `Linux` or `WindowsContainer`."

  validation {
    condition     = contains(["Windows", "Linux", "WindowsContainer", "WindowsManagedInstance"], var.os_type)
    error_message = "The operating system type must be one of: `Windows`, `Linux`, or `WindowsContainer`."
  }
}

variable "parent_id" {
  type        = string
  description = "The resource ID of the resource group in which to create this resource."
  nullable    = false
}

variable "app_service_environment_id" {
  type        = string
  default     = null
  description = "Optional: The ID of the App Service Environment."
}

variable "diagnostic_settings" {
  type = map(object({
    name = optional(string, null)
    logs = optional(set(object({
      category       = optional(string, null)
      category_group = optional(string, null)
      enabled        = optional(bool, true)
      retention_policy = optional(object({
        days    = optional(number, 0)
        enabled = optional(bool, false)
      }), {})
    })), [])
    metrics = optional(set(object({
      category = optional(string, null)
      enabled  = optional(bool, true)
      retention_policy = optional(object({
        days    = optional(number, 0)
        enabled = optional(bool, false)
      }), {})
    })), [])
    log_analytics_destination_type           = optional(string, "Dedicated")
    workspace_resource_id                    = optional(string, null)
    storage_account_resource_id              = optional(string, null)
    event_hub_authorization_rule_resource_id = optional(string, null)
    event_hub_name                           = optional(string, null)
    marketplace_partner_resource_id          = optional(string, null)
  }))
  default     = {}
  description = <<DESCRIPTION
  A map of diagnostic settings to create on the App Service Environment (ASE). The map key is deliberately arbitrary to avoid issues where map keys maybe unknown at plan time.

  - `name` - (Optional) The name of the diagnostic setting. One will be generated if not set, however this will not be unique if you want to create multiple diagnostic setting resources.
  - `log_categories` - (Optional) A set of log categories to send to the log analytics workspace. Defaults to `[]`.
  - `log_groups` - (Optional) A set of log groups to send to the log analytics workspace. Defaults to `["allLogs"]`.
  - `metric_categories` - (Optional) A set of metric categories to send to the log analytics workspace. Defaults to `["AllMetrics"]`.
  - `log_analytics_destination_type` - (Optional) The destination type for the diagnostic setting. Possible values are `Dedicated` and `AzureDiagnostics`. Defaults to `Dedicated`.
  - `workspace_resource_id` - (Optional) The resource ID of the log analytics workspace to send logs and metrics to.
  - `storage_account_resource_id` - (Optional) The resource ID of the storage account to send logs and metrics to.
  - `event_hub_authorization_rule_resource_id` - (Optional) The resource ID of the event hub authorization rule to send logs and metrics to.
  - `event_hub_name` - (Optional) The name of the event hub. If none is specified, the default event hub will be selected.
  - `marketplace_partner_resource_id` - (Optional) The full ARM resource ID of the Marketplace resource to which you would like to send Diagnostic Logs.
  DESCRIPTION
  nullable    = false

  validation {
    condition     = alltrue([for _, v in var.diagnostic_settings : contains(["Dedicated", "AzureDiagnostics"], v.log_analytics_destination_type)])
    error_message = "Log analytics destination type must be one of: 'Dedicated', 'AzureDiagnostics'."
  }
  validation {
    condition = alltrue(
      [
        for _, v in var.diagnostic_settings :
        v.workspace_resource_id != null || v.storage_account_resource_id != null || v.event_hub_authorization_rule_resource_id != null || v.marketplace_partner_resource_id != null
      ]
    )
    error_message = "At least one of `workspace_resource_id`, `storage_account_resource_id`, `marketplace_partner_resource_id`, or `event_hub_authorization_rule_resource_id`, must be set."
  }
}

variable "enable_telemetry" {
  type        = bool
  default     = true
  description = <<DESCRIPTION
This variable controls whether or not telemetry is enabled for the module.
For more information see <https://aka.ms/avm/telemetryinfo>.
If it is set to false, then no telemetry will be collected.
DESCRIPTION
  nullable    = false
}

variable "install_scripts" {
  type = list(object({
    name = string
    source = object({
      type       = optional(string, "RemoteAzureBlob")
      source_uri = string
    })
  }))
  default     = null
  description = <<DESCRIPTION
  Optional: A list of install scripts to run on the Managed Instance App Service Plan. Only applicable when `os_type` is `WindowsManagedInstance`.

  - `name` - (Required) The name of the install script (e.g. `"FontInstaller"`).
  - `source` - (Required) The source configuration for the install script.
    - `type` - (Optional) The type of the source. Defaults to `"RemoteAzureBlob"`.
    - `source_uri` - (Required) The URI of the install script package (e.g. a blob URI to a `.zip` file).
  DESCRIPTION
}

variable "lock" {
  type = object({
    kind = string
    name = optional(string, null)
  })
  default     = null
  description = <<DESCRIPTION
  Controls the Resource Lock configuration for this resource. The following properties can be specified:

  - `kind` - (Required) The type of lock. Possible values are `\"CanNotDelete\"` and `\"ReadOnly\"`.
  - `name` - (Optional) The name of the lock. If not specified, a name will be generated based on the `kind` value. Changing this forces the creation of a new resource.
  DESCRIPTION

  validation {
    condition     = var.lock != null ? contains(["CanNotDelete", "ReadOnly"], var.lock.kind) : true
    error_message = "Lock kind must be either `\"CanNotDelete\"` or `\"ReadOnly\"`."
  }
}

variable "managed_identities" {
  type = object({
    system_assigned            = optional(bool, false)
    user_assigned_resource_ids = optional(set(string), [])
  })
  default     = {}
  description = <<DESCRIPTION
  Controls the managed identity configuration on this resource. The following properties can be specified:

  - `system_assigned` - (Optional) Specifies if the System Assigned Managed Identity should be enabled.
  - `user_assigned_resource_ids` - (Optional) Specifies a list of User Assigned Managed Identity resource IDs to be assigned to this resource.
  DESCRIPTION
  nullable    = false
}

variable "maximum_elastic_worker_count" {
  type        = number
  default     = 3
  description = "The maximum number of total workers allowed for this ElasticScaleEnabled App Service Plan."
}

variable "per_site_scaling_enabled" {
  type        = bool
  default     = false
  description = "Should per site scaling be enabled for this App Service Plan."
}

variable "plan_default_identity" {
  type = object({
    identity_type                      = optional(string, "UserAssigned")
    user_assigned_identity_resource_id = string
  })
  default     = null
  description = <<DESCRIPTION
  Optional: The default identity configuration for the Managed Instance App Service Plan. Only applicable when `os_type` is `WindowsManagedInstance`.

  - `identity_type` - (Optional) The type of the identity. Defaults to `"UserAssigned"`.
  - `user_assigned_identity_resource_id` - (Required) The resource ID of the user-assigned managed identity to use as the plan default identity.
  DESCRIPTION
}

variable "premium_plan_auto_scale_enabled" {
  type        = bool
  default     = false
  description = "Defaults to false. Should elastic scale be enabled for this App Service Plan. Only set to true if deploying a Premium or Elastic Premium SKU."
}

variable "rdp_enabled" {
  type        = bool
  default     = null
  description = "Optional: Whether RDP is enabled for the Managed Instance App Service Plan. Only applicable when `os_type` is `WindowsManagedInstance`. Set to `null` for non-managed instance plans. A Bastion host with must be deployed in the virtual network for RDP connectivity to work."
}

variable "registry_adapters" {
  type = list(object({
    registry_key = string
    type         = string
    key_vault_secret_reference = object({
      secret_uri = string
    })
  }))
  default     = null
  description = <<DESCRIPTION
  Optional: A list of registry adapters associated with this App Service Plan. Only applicable when `os_type` is `WindowsManagedInstance`.

  - `registry_key` - (Required) Registry key for the adapter. The registry key must start with `HKEY_LOCAL_MACHINE`, `HKEY_CURRENT_USER`, or `HKEY_USERS` and contain at least one forward slash (e.g. `HKEY_LOCAL_MACHINE/SOFTWARE/MyApp/Config`).
  - `type` - (Required) Type of the registry adapter. Possible values are `"DWORD"` or`"String"`.
  - `key_vault_secret_reference` - (Required) Key vault reference to the value that will be placed in the registry location.
    - `secret_uri` - (Required) The URI of the Key Vault secret.
  DESCRIPTION

  validation {
    condition = var.registry_adapters != null ? alltrue([
      for adapter in var.registry_adapters : contains(["DWORD", "String"], adapter.type)
    ]) : true
    error_message = "The registry adapter type must be one of: `DWORD` or `String`."
  }
}

variable "retry" {
  type = object({
    error_message_regex  = optional(list(string), ["ScopeLocked"])
    interval_seconds     = optional(number, null)
    max_interval_seconds = optional(number, null)
  })
  default     = null
  description = <<DESCRIPTION
  The retry configuration for azapi resources. The following properties can be specified:

  - `error_message_regex` - (Required) A list of regular expressions to match against error messages. If any match, the request will be retried.
  - `interval_seconds` - (Optional) The base number of seconds to wait between retries. Default is `10`.
  - `max_interval_seconds` - (Optional) The maximum number of seconds to wait between retries. Default is `180`.
  DESCRIPTION
}

variable "role_assignments" {
  type = map(object({
    role_definition_id_or_name             = string
    principal_id                           = string
    description                            = optional(string, null)
    skip_service_principal_aad_check       = optional(bool, false)
    condition                              = optional(string, null)
    condition_version                      = optional(string, null)
    delegated_managed_identity_resource_id = optional(string, null)
    principal_type                         = optional(string, null)
  }))
  default     = {}
  description = <<DESCRIPTION
  A map of role assignments to create on the resource. The map key is deliberately arbitrary to avoid issues where map keys maybe unknown at plan time.

  - `role_definition_id_or_name` - The ID or name of the role definition to assign to the principal.
  - `principal_id` - The ID of the principal to assign the role to.
  - `description` - (Optional) The description of the role assignment.
  - `skip_service_principal_aad_check` - (Optional) No effect when using AzAPI. Defaults to false.
  - `condition` - (Optional) The condition which will be used to scope the role assignment.
  - `condition_version` - (Optional) The version of the condition syntax. Leave as `null` if you are not using a condition, if you are then valid values are `2.0`.
  - `delegated_managed_identity_resource_id` - (Optional) The delegated Azure Resource Id which contains a Managed Identity. Changing this forces a new resource to be created. This field is only used in cross-tenant scenario.
  - `principal_type` - (Optional) The type of the `principal_id`. Possible values are `User`, `Group` and `ServicePrincipal`. It is necessary to explicitly set this attribute when creating role assignments if the principal creating the assignment is constrained by ABAC rules that filters on the PrincipalType attribute.

  > Note: only set `skip_service_principal_aad_check` to true if you are assigning a role to a service principal.
  DESCRIPTION
  nullable    = false
}

variable "server_farm_resource_type" {
  type        = string
  default     = "Microsoft.Web/serverfarms@2025-03-01"
  description = "The resource type for the server farm. Defaults to `Microsoft.Web/serverfarms`."
}

variable "sku_name" {
  type        = string
  default     = "P1v2" # P1v2 is the minimum SKU for zone redundancy
  description = "The SKU name of the service plan. Defaults to `P1v2`."

  validation {
    condition     = can(regex("^(B1|B2|B3|D1|F1|I1|I2|I3|I1v2|I2v2|I3v2|I4v2|I5v2|I6v2|P1v2|P2v2|P3v2|P0v3|P1v3|P2v3|P3v3|P1mv3|P2mv3|P3mv3|P4mv3|P5mv3|P0v4|P1v4|P2v4|P3v4|P1mv4|P2mv4|P3mv4|P4mv4|P5mv4|S1|S2|S3|SHARED|EP1|EP2|EP3|FC1|WS1|WS2|WS3|Y1)$", var.sku_name))
    error_message = "The SKU name must be B1, B2, B3, D1, F1, I1, I2, I3, I1v2, I2v2, I3v2, I4v2, I5v2, I6v2, P1v2, P2v2, P3v2, P0v3, P1v3, P2v3, P3v3, P1mv3, P2mv3, P3mv3, P4mv3, P5mv3, S1, S2, S3, SHARED, EP1, EP2, EP3, FC1, WS1, WS2, WS3, or Y1."
  }
}

variable "storage_mounts" {
  type = list(object({
    name             = string
    type             = optional(string, "LocalStorage")
    source           = optional(string, "")
    destination_path = string
    credentials_key_vault_reference = optional(object({
      secret_uri = optional(string)
    }), {})
  }))
  default     = null
  description = <<DESCRIPTION
  Optional: A list of storage mounts to configure on the App Service Plan. Only applicable when `os_type` is `WindowsManagedInstance`.

  - `name` - (Required) The name of the storage mount (e.g. `"g-drive"`).
  - `type` - (Optional) The type of the storage mount. Defaults to `"LocalStorage"`.
  - `source` - (Optional) The source of the storage mount. Defaults to `""`.
  - `destination_path` - (Required) The destination path for the storage mount (e.g. `"G:\\"`).
  - `credentials_key_vault_reference` - (Optional) A Key Vault reference for storage credentials.
    - `secret_uri` - (Required) The URI of the Key Vault secret.
  DESCRIPTION
}

variable "tags" {
  type        = map(string)
  default     = null
  description = "Tags of the resource."
}

variable "timeouts" {
  type = object({
    create = optional(string, null)
    delete = optional(string, null)
    read   = optional(string, null)
    update = optional(string, null)
  })
  default     = null
  description = <<DESCRIPTION
  The timeout configuration for azapi resources. The following properties can be specified:

  - `create` - (Optional) The timeout for create operations e.g. `"30m"`, `"1h"`.
  - `delete` - (Optional) The timeout for delete operations e.g. `"30m"`, `"1h"`.
  - `read` - (Optional) The timeout for read operations e.g. `"30m"`, `"1h"`.
  - `update` - (Optional) The timeout for update operations e.g. `"30m"`, `"1h"`.
  DESCRIPTION
}

variable "virtual_network_subnet_id" {
  type        = string
  default     = null
  description = "Optional: The resource ID of the subnet to integrate the App Service Plan with. This enables VNet integration for the plan."
}

variable "worker_count" {
  type        = number
  default     = 3
  description = "The number of workers to allocate for this App Service Plan. Defaults to `3`, which is the recommended minimum for production workloads."
}

variable "zone_balancing_enabled" {
  type        = bool
  default     = true
  description = "Should zone balancing be enabled for this App Service Plan? Defaults to `true`."
}
