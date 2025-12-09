# A resource module MUST use location as a standard input
# Please see https://azure.github.io/Azure-Verified-Modules/specs/shared/#id-rmnfr2---category-inputs---parametervariable-naming
variable "location" {
  type        = string
  description = "The location where the resources will be deployed."
  nullable    = false # Once migration from data sources is complete, this should be uncommented
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
    condition     = can(regex("Windows|Linux|WindowsContainer", var.os_type))
    error_message = "The operating system type must be one of: `Windows`, `Linux`, or `WindowsContainer`."
  }
}

# This is required for most resource modules
variable "resource_group_name" {
  type        = string
  description = "The resource group where the resources will be deployed."
}

variable "app_service_environment_id" {
  type        = string
  default     = null
  description = "Optional: The ID of the App Service Environment."
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

variable "maximum_elastic_worker_count" {
  type        = number
  default     = null
  description = "The minimum number of workers to allocate for this App Service Plan."
}

variable "per_site_scaling_enabled" {
  type        = bool
  default     = false
  description = "Should per site scaling be enabled for this App Service Plan."
}

variable "premium_plan_auto_scale_enabled" {
  type        = bool
  default     = false
  description = "Defaults to false. Should auto scaling be enabled for this App Service Plan. Only set to true if deploying a Premium SKU."
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
  A map of role assignments to create on the <RESOURCE>. The map key is deliberately arbitrary to avoid issues where map keys maybe unknown at plan time.

  - `role_definition_id_or_name` - The ID or name of the role definition to assign to the principal.
  - `principal_id` - The ID of the principal to assign the role to.
  - `description` - (Optional) The description of the role assignment.
  - `skip_service_principal_aad_check` - (Optional) If set to true, skips the Azure Active Directory check for the service principal in the tenant. Defaults to false.
  - `condition` - (Optional) The condition which will be used to scope the role assignment.
  - `condition_version` - (Optional) The version of the condition syntax. Leave as `null` if you are not using a condition, if you are then valid values are `2.0`.
  - `delegated_managed_identity_resource_id` - (Optional) The delegated Azure Resource Id which contains a Managed Identity. Changing this forces a new resource to be created. This field is only used in cross-tenant scenario.
  - `principal_type` - (Optional) The type of the `principal_id`. Possible values are `User`, `Group` and `ServicePrincipal`. It is necessary to explicitly set this attribute when creating role assignments if the principal creating the assignment is constrained by ABAC rules that filters on the PrincipalType attribute.

  > Note: only set `skip_service_principal_aad_check` to true if you are assigning a role to a service principal.
  DESCRIPTION
  nullable    = false
}

variable "sku_name" {
  type        = string
  default     = "P1v2" # P1v2 is the minimum SKU for zone redundancy
  description = "The SKU name of the service plan. Defaults to `P1v2`."

  validation {
    condition     = can(regex("B1|B2|B3|D1|F1|I1|I2|I3|I1v2|I2v2|I3v2|I4v2|I5v2|I6v2|P1v2|P2v2|P3v2|P0v3|P1v3|P2v3|P3v3|P1mv3|P2mv3|P3mv3|P4mv3|P5mv3|P0v4|P1v4|P2v4|P3v4|P1mv4|P2mv4|P3mv4|P4mv4|P5mv4|S1|S2|S3|SHARED|EP1|EP2|EP3|FC1|WS1|WS2|WS3|Y1", var.sku_name))
    error_message = "The SKU name must be B1, B2, B3, D1, F1, I1, I2, I3, I1v2, I2v2, I3v2, I4v2, I5v2, I6v2, P1v2, P2v2, P3v2, P0v3, P1v3, P2v3, P3v3, P1mv3, P2mv3, P3mv3, P4mv3, P5mv3, S1, S2, S3, SHARED, EP1, EP2, EP3, FC1, WS1, WS2, WS3, and Y1."
  }
}

# tflint-ignore: terraform_unused_declarations
variable "tags" {
  type        = map(string)
  default     = null
  description = "Tags of the resource."
}

variable "worker_count" {
  type        = number
  default     = 3
  description = "The number of workers to allocate for this App Service Plan."

  validation {
    condition     = (var.zone_balancing_enabled && var.sku_name != "Y1") ? var.worker_count >= 2 : true
    error_message = "When zone_balancing_enabled is true, worker_count must be at least 2."
  }
}

variable "zone_balancing_enabled" {
  type        = bool
  default     = true
  description = "Should zone balancing be enabled for this App Service Plan? Defaults to `true`."
}
