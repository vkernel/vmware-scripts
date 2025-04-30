output "tenant_tag" {
  description = "The tenant tag used for this tenant"
  value       = local.tenant_tag
}

output "tenant_vms" {
  description = "List of all VMs in the tenant"
  value = flatten([
    for env_key, env_data in local.environments : [
      for app_key, app_data in env_data : [
        for sub_app_key, sub_app_vms in app_data : [
          for vm in sub_app_vms : vm
          if can(sub_app_vms[0])
        ]
        if can(sub_app_vms[0])
      ]
    ]
  ])
} 