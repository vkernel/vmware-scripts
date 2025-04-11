output "application_tags" {
  description = "List of tenant-application tags"
  value       = local.tenant_app_pairs
}

output "environment_tags" {
  description = "List of environment tags"
  value       = local.environments
}

output "application_groups_created" {
  description = "List of application groups created"
  value       = [for group in nsxt_policy_group.app_groups : group.display_name]
}

output "environment_groups_created" {
  description = "List of environment groups created"
  value       = [for group in nsxt_policy_group.environment_groups : group.display_name]
}

output "application_policies_created" {
  description = "List of created application security policies"
  value       = [nsxt_policy_security_policy.application_policy.display_name]
}

output "vm_count" {
  description = "Number of VMs tagged"
  value       = length(nsxt_policy_vm_tags.vm_tags)
} 