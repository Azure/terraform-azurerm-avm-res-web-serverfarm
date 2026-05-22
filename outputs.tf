output "name" {
  description = "Name of the app service plan"
  value       = azapi_resource.this.name
}

output "resource_id" {
  description = "Resource id of the app service plan"
  value       = azapi_resource.this.id
}
