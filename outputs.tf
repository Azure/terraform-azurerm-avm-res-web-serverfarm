output "name" {
  description = "Name of the app service plan"
  value       = azurerm_service_plan.this.name
}

# Technically optional, but will allow users of module to access other useful information
output "resource" {
  description = "The full output of the resource."
  value       = azurerm_service_plan.this
}

output "resource_id" {
  description = "Resource id of the app service plan"
  value       = azurerm_service_plan.this.id
}
