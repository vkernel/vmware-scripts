terraform {
  required_providers {
    nsxt = {
      source = "vmware/nsxt"
    }
  }
}

locals {
  tenant_key = var.tenant_id
  tenant_data = var.inventory[local.tenant_key]
  
  # Create tenant tag
  tenant_tag = "ten-${local.tenant_key}"
  
  # Extract all environments
  environments = try(local.tenant_data.internal, {})
  
  # Extract emergency data
  emergency = try(local.tenant_data.emergency, {})
  
  # Create a flat list of all applications and sub-applications
  applications = flatten([
    for env_key, env_data in local.environments : [
      for app_key, app_data in env_data : {
        env_key = env_key
        app_key = app_key
        is_sub_app = false
        sub_apps = try(
          [
            for sub_app_key, sub_app_data in app_data : 
            {
              env_key = env_key
              app_key = app_key
              sub_app_key = sub_app_key
              is_sub_app = true
            }
            if can(sub_app_data[0])  # Check if it's a list of VMs
          ], 
          []
        )
      }
    ]
  ])
  
  # Create a flat list of all VMs with their full hierarchy information
  all_vm_data = flatten([
    for env_key, env_data in local.environments : [
      for app_key, app_data in env_data : [
        for sub_app_key, sub_app_vms in app_data : [
          for vm in sub_app_vms : {
            vm = vm
            env_key = env_key
            app_key = app_key
            sub_app_key = sub_app_key
            hierarchy = {
              tenant = local.tenant_tag
              environment = env_key
              application = app_key
              sub_application = sub_app_key != app_key ? sub_app_key : null
            }
          }
          if can(sub_app_vms[0])
        ]
        if can(sub_app_vms[0])
      ]
    ]
  ])
  
  # Create a set of all VM names for data lookup
  all_vms = toset([for vm_data in local.all_vm_data : vm_data.vm])
  
  # Create comprehensive VM tags mapping for all hierarchy levels
  vm_hierarchy_tags = {
    for vm_data in local.all_vm_data : vm_data.vm => {
      tenant = local.tenant_tag
      environment = vm_data.env_key
      application = vm_data.app_key
      sub_application = vm_data.sub_app_key != vm_data.app_key ? vm_data.sub_app_key : null
    }
  }
  
  # Create mapping for emergency tags
  emergency_vms = flatten([
    for emergency_key, emergency_vms in local.emergency : [
      for vm in emergency_vms : {
        vm = vm
        emergency_key = emergency_key
      }
    ]
  ])
  
  # Map emergency VMs to their tags
  emergency_vm_tags = {
    for vm_data in local.emergency_vms : vm_data.vm => vm_data.emergency_key
  }
}

# Get VM instances by display name
data "nsxt_policy_vm" "vms" {
  for_each = local.all_vms
  
  display_name = each.value
}

# Apply all hierarchy tags to VMs
resource "nsxt_policy_vm_tags" "hierarchy_tags" {
  for_each = local.all_vms
  
  instance_id = data.nsxt_policy_vm.vms[each.value].external_id
  
  # Tenant tag
  tag {
    scope = "tenant"
    tag   = local.vm_hierarchy_tags[each.value].tenant
  }
  
  # Environment tag
  tag {
    scope = "environment"
    tag   = local.vm_hierarchy_tags[each.value].environment
  }
  
  # Application tag 
  tag {
    scope = "application"
    tag   = local.vm_hierarchy_tags[each.value].application
  }
  
  # Sub-application tag (if present)
  dynamic "tag" {
    for_each = local.vm_hierarchy_tags[each.value].sub_application != null ? [1] : []
    content {
      scope = "sub-application"
      tag   = local.vm_hierarchy_tags[each.value].sub_application
    }
  }
  
  # Emergency tag (if present)
  dynamic "tag" {
    for_each = contains(keys(local.emergency_vm_tags), each.value) ? [1] : []
    content {
      scope = "emergency"
      tag   = local.emergency_vm_tags[each.value]
    }
  }
} 