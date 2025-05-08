output "tenant_tags" {
  description = "Tenant tags created for each deployment"
  value       = { for tenant_id, tag in module.tags : tenant_id => tag.tenant_tag }
}

output "tenant_vms" {
  description = "List of VMs in each tenant"
  value       = { for tenant_id, tag in module.tags : tenant_id => tag.tenant_vms }
}

output "tenant_group_ids" {
  description = "ID of each tenant group"
  value       = { for tenant_id, group in module.groups : tenant_id => group.tenant_group_id }
}

output "environment_groups" {
  description = "Map of environment group IDs for each tenant"
  value       = { for tenant_id, group in module.groups : tenant_id => group.environment_groups }
}

output "application_groups" {
  description = "Map of application group IDs for each tenant"
  value       = { for tenant_id, group in module.groups : tenant_id => group.application_groups }
}

output "services" {
  description = "Services created for each tenant"
  value       = { for tenant_id, service in module.services : tenant_id => service.services }
} 