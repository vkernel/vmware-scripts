output "tenant_tag" {
  description = "Tenant tag created for this deployment"
  value       = module.tags.tenant_tag
}

output "tenant_vms" {
  description = "List of VMs in this tenant"
  value       = module.tags.tenant_vms
}

output "tenant_group_id" {
  description = "ID of the tenant group"
  value       = module.groups.tenant_group_id
}

output "environment_groups" {
  description = "Map of environment group IDs"
  value       = module.groups.environment_groups
}

output "application_groups" {
  description = "Map of application group IDs"
  value       = module.groups.application_groups
}

output "services" {
  description = "Services created for the tenant"
  value       = module.services.services
} 