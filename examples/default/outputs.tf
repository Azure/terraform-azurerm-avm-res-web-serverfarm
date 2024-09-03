output "location" {
  description = "Location of the app service plan"
  value       = module.test.resource.location
}

output "name" {
  description = "Name of the app service plan"
  value       = module.test.name
}

output "resource_id" {
  description = "Name of the app service plan"
  value       = module.test.resource_id
}

output "sku_name" {
  description = "Name of the app service plan"
  value       = module.test.resource.sku_name
}

output "worker_count" {
  description = "Name of the app service plan"
  value       = module.test.resource.worker_count
}

output "zone_mappings" {
  description = "Name of the app service plan"
  value       = module.test.zone_mappings
}

output "zone_redundant" {
  description = "Name of the app service plan"
  value       = module.test.resource.zone_balancing_enabled
}
