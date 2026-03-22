output "plan_names" {
  description = "Names of the deployed app service plans"
  value       = { for k, v in module.test : k => v.name }
}

output "plan_resource_ids" {
  description = "Resource IDs of the deployed app service plans"
  value       = { for k, v in module.test : k => v.resource_id }
}
