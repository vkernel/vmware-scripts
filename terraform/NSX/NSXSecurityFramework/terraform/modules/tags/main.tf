terraform {
  required_providers {
    nsxt = {
      source = "vmware/nsxt"
    }
  }
}

locals {
  tenant_key = var.tenant_id

  # Get the tenant inventory data
  tenant_data = var.inventory[local.tenant_key]
  
  # Create tag format for tenant
  tenant_tag = "ten-${local.tenant_key}"
  
  # Extract environment data
  environments = local.tenant_data.internal
  
  # Process direct VMs (no sub-applications)
  direct_vms = flatten([
    for env_key, env in local.environments : [
      for app_key, app in env : 
        # Only process apps that have a direct VM list (can index with [0])
        can(app[0]) ? [
          for vm in app : {
            vm = vm
            env_key = env_key
            app_key = app_key
            sub_app_key = null
          }
        ] : []
    ]
  ])
  
  # Process VMs in sub-applications
  sub_app_vms = flatten([
    for env_key, env in local.environments : [
      for app_key, app in env : 
        # Only process apps that have sub-applications (can't index with [0])
        !can(app[0]) ? flatten([
          for sub_app_key, sub_app in app : [
            for vm in sub_app : {
              vm = vm
              env_key = env_key
              app_key = app_key
              sub_app_key = sub_app_key
            }
          ]
        ]) : []
    ]
  ])
  
  # Combine both types of VMs and deduplicate by VM name
  all_vm_data_combined = concat(local.direct_vms, local.sub_app_vms)
  
  # Choose one VM data entry for each VM name (prioritize sub-application VMs)
  all_vm_data = {
    for vm_data in local.all_vm_data_combined : vm_data.vm => vm_data...
  }
  
  # Set of all VM names (deduplicated)
  all_vms = toset(keys(local.all_vm_data))
  
  # Find sub-applications for each VM (if available)
  sub_apps_by_vm = {
    for vm_name, vm_data_list in local.all_vm_data :
      vm_name => [for d in vm_data_list : d.sub_app_key if d.sub_app_key != null]
  }
  
  # Map of VM to its hierarchy tags - use VM name as the key
  vm_hierarchy_tags = {
    for vm_name, vm_data_list in local.all_vm_data : vm_name => {
      tenant = local.tenant_tag
      environment = vm_data_list[0].env_key
      application = vm_data_list[0].app_key
      sub_application = length(local.sub_apps_by_vm[vm_name]) > 0 ? local.sub_apps_by_vm[vm_name][0] : null
    }
  }
  
  # Emergency stuff, if any
  emergency = try(local.tenant_data.emergency, null)
  
  # Create a mapping of VM name to its emergency group key
  emergency_vm_tags = merge([
    for emg_key, emg_list in local.emergency : {
      for vm in emg_list : vm => emg_key
    }
  ]...)
  
  # Derive the list of emergency VMs from the keys of the mapping
  emergency_vms = keys(local.emergency_vm_tags)
}

# Get VM instances by display name
data "nsxt_policy_vm" "vms" {
  for_each = local.all_vms
  
  display_name = each.value
}

# Apply all hierarchy tags to VMs
resource "nsxt_policy_vm_tags" "hierarchy_tags" {
  for_each = local.vm_hierarchy_tags
  
  instance_id = data.nsxt_policy_vm.vms[each.key].instance_id
  
  # Tenant tag
  tag {
    scope = "tenant"
    tag   = each.value.tenant
  }
  
  # Environment tag
  tag {
    scope = "environment"
    tag   = each.value.environment
  }
  
  # Application tag 
  tag {
    scope = "application"
    tag   = each.value.application
  }
  
  # Sub-application tag (if present)
  dynamic "tag" {
    for_each = each.value.sub_application != null ? [each.value.sub_application] : []
    content {
      scope = "sub-application"
      tag   = tag.value
    }
  }
  
  # Emergency tag (if present)
  dynamic "tag" {
    for_each = lookup(local.emergency_vm_tags, each.key, null) != null ? [local.emergency_vm_tags[each.key]] : []
    content {
      scope = "emergency"
      tag   = tag.value
    }
  }
} 