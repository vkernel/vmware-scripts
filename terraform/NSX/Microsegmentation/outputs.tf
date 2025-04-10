output "application_tags_created" {
  description = "List of tenant-application tags created"
  value       = [for tag in nsxt_policy_tag.tenant_app_tags : tag.tag]
}

output "environment_tags_created" {
  description = "List of environment tags created"
  value       = [for tag in nsxt_policy_tag.environment_tags : tag.tag]
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
  description = "List of application-specific security policies created"
  value       = [for policy in nsxt_policy_security_policy.application_policies : policy.display_name]
}

output "vm_count" {
  description = "Number of VMs tagged"
  value       = length(nsxt_policy_vm_tags.vm_tags)
} 