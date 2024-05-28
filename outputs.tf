output "name" {
  description = "Name of the app service plan"
  value       = azurerm_service_plan.this.name
}

# Module owners should include the full resource via a 'resource' output
# https://azure.github.io/Azure-Verified-Modules/specs/terraform/#id-tffr2---category-outputs---additional-terraform-outputs
output "resource" {
  description = "This is the full output for the resource."
  value       = azurerm_service_plan.this
}

output "resource_id" {
  description = "Resource id of the app service plan"
  value       = azurerm_service_plan.this.id
}
