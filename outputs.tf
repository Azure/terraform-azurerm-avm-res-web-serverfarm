output "name" {
  description = "Name of the app service plan"
  value       = azapi_resource.this.name
}

# Technically optional, but will allow users of module to access other useful information
output "resource" {
  description = "The full output of the resource."
  value       = azapi_resource.this
}

output "resource_id" {
  description = "Resource id of the app service plan"
  value       = azapi_resource.this.id
}
