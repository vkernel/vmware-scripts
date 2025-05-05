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
  
  # Set of all VM names (deduplicated)
  all_vms = toset([for vm_data in local.all_vm_data_combined : vm_data.vm])
  
  # Map VM→all application keys it belongs to
  app_tags_by_vm = {
    for vm in local.all_vms :
    vm => distinct([
      for d in local.all_vm_data_combined :
      d.app_key if d.vm == vm
    ])
  }

  # Map VM→all sub-application keys if any
  sub_app_tags_by_vm = {
    for vm in local.all_vms :
    vm => distinct([
      for d in local.all_vm_data_combined :
      d.sub_app_key if d.vm == vm && d.sub_app_key != null
    ])
  }
  
  # Get a single entry per VM for tenant and environment tags
  # We can use any entry since tenant/env should be the same regardless of app/sub-app
  vm_base_data = {
    for vm in local.all_vms : vm => (
      [for d in local.all_vm_data_combined : d if d.vm == vm][0]
    )
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
  for_each = local.vm_base_data
  
  instance_id = data.nsxt_policy_vm.vms[each.key].instance_id
  
  # Tenant tag
  tag {
    scope = "tenant"
    tag   = local.tenant_tag
  }
  
  # Environment tag
  tag {
    scope = "environment"
    tag   = each.value.env_key
  }
  
  # Application tags - one per app this VM belongs to
  dynamic "tag" {
    for_each = local.app_tags_by_vm[each.key]
    content {
      scope = "application"
      tag   = tag.value
    }
  }
  
  # Sub-application tags - one per sub-app this VM belongs to
  dynamic "tag" {
    for_each = local.sub_app_tags_by_vm[each.key]
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