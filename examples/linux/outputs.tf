output "name" {
  description = "Name of the app service plan"
  value       = module.test.name
}

output "resource_id" {
  description = "Resource ID of the app service plan"
  value       = module.test.resource_id
}
