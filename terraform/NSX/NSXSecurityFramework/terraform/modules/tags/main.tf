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
  
  # Flatten VM list for environment tags
  environment_vm_tags = {
    for pair in flatten([
      for env_key, env_data in local.environments : [
        for app_key, app_data in env_data : [
          for sub_app_key, sub_app_vms in app_data : [
            for vm in sub_app_vms : {
              key = "${vm}|${env_key}"
              vm = vm
              env_key = env_key
            }
            if can(sub_app_vms[0])
          ]
          if can(sub_app_vms[0])
        ]
      ]
    ]) : pair.key => pair
  }
  
  # Flatten VM list for application tags
  application_vm_tags = {
    for pair in flatten([
      for env_key, env_data in local.environments : [
        for app_key, app_data in env_data : [
          for sub_app_key, sub_app_vms in app_data : [
            for vm in sub_app_vms : {
              key = "${vm}|${app_key}"
              vm = vm
              app_key = app_key
            }
            if can(sub_app_vms[0])
          ]
          if can(sub_app_vms[0])
        ]
      ]
    ]) : pair.key => pair
  }
  
  # Flatten VM list for sub-application tags
  sub_application_vm_tags = {
    for pair in flatten([
      for env_key, env_data in local.environments : [
        for app_key, app_data in env_data : [
          for sub_app_key, sub_app_vms in app_data : [
            for vm in sub_app_vms : {
              key = "${vm}|${sub_app_key}"
              vm = vm
              sub_app_key = sub_app_key
            }
            if can(sub_app_vms[0]) && sub_app_key != app_key
          ]
          if can(sub_app_vms[0])
        ]
      ]
    ]) : pair.key => pair
  }
  
  # Create a set of all VM names for data lookup
  all_vms = toset(flatten([
    for env_key, env_data in local.environments : [
      for app_key, app_data in env_data : [
        for sub_app_key, sub_app_vms in app_data : [
          for vm in sub_app_vms : vm
          if can(sub_app_vms[0])
        ]
        if can(sub_app_vms[0])
      ]
    ]
  ]))
}

# Get VM instances by display name
data "nsxt_policy_vm" "vms" {
  for_each = local.all_vms
  
  display_name = each.value
}

# Create tenant tag
resource "nsxt_policy_vm_tags" "tenant_tag" {
  for_each = local.all_vms
  
  instance_id = data.nsxt_policy_vm.vms[each.value].external_id
  tag {
    scope = "tenant"
    tag   = local.tenant_tag
  }
}

# Create environment tags
resource "nsxt_policy_vm_tags" "environment_tags" {
  for_each = local.environment_vm_tags
  
  instance_id = data.nsxt_policy_vm.vms[each.value.vm].external_id
  tag {
    scope = "environment"
    tag   = each.value.env_key
  }
  
  depends_on = [nsxt_policy_vm_tags.tenant_tag]
}

# Create application tags
resource "nsxt_policy_vm_tags" "application_tags" {
  for_each = local.application_vm_tags
  
  instance_id = data.nsxt_policy_vm.vms[each.value.vm].external_id
  tag {
    scope = "application"
    tag   = each.value.app_key
  }
  
  depends_on = [nsxt_policy_vm_tags.environment_tags]
}

# Create sub-application tags
resource "nsxt_policy_vm_tags" "sub_application_tags" {
  for_each = local.sub_application_vm_tags
  
  instance_id = data.nsxt_policy_vm.vms[each.value.vm].external_id
  tag {
    scope = "sub-application"
    tag   = each.value.sub_app_key
  }
  
  depends_on = [nsxt_policy_vm_tags.application_tags]
} 