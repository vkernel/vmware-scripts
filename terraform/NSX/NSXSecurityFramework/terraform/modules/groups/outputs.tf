output "tenant_group_id" {
  description = "ID of the tenant group"
  value       = nsxt_policy_group.tenant_group.path
}

output "environment_groups" {
  description = "Map of environment group paths"
  value = {
    for env_key, env in nsxt_policy_group.environment_groups : env_key => env.path
  }
}

output "application_groups" {
  description = "Map of application group paths"
  value = {
    for app_key, app in nsxt_policy_group.application_groups : app_key => app.path
  }
}

output "sub_application_groups" {
  description = "Map of sub-application group paths"
  value = {
    for sub_app_key, sub_app in nsxt_policy_group.sub_application_groups : sub_app_key => sub_app.path
  }
}

output "external_service_groups" {
  description = "Map of external service group paths"
  value = {
    for ext_key, ext in nsxt_policy_group.external_service_groups : ext_key => ext.path
  }
}

output "emergency_groups" {
  description = "Map of emergency group paths"
  value = {
    for emergency_key, emergency in nsxt_policy_group.emergency_groups : emergency_key => emergency.path
  }
} 