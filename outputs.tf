output "name" {
  description = "Name of the app service plan"
  value       = azurerm_service_plan.this.name
}

output "resource_id" {
  description = "Resource id of the app service plan"
  value       = azurerm_service_plan.this.id
}
