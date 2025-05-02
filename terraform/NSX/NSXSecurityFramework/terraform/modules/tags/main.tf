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
  tenant_tag = "${local.tenant_key}"
  
  # Extract environment data
  environments = local.tenant_data.internal
  
  # List of all VMs with their hierachy information
  all_vm_data = distinct(flatten([
    # Process all environments
    for env_key, env in local.environments : flatten([
      # Process all applications in each environment
      for app_key, app in env : flatten([
        # Check if this app has sub-applications or direct VMs
        can(app[0]) ? 
          # This is a direct VM list (e.g., in test environment)
          flatten([
            [
              for vm in app : {
                vm = vm
                env_key = env_key
                app_key = app_key
                sub_app_key = app_key  # Use app key as sub_app_key
                vm_index = "${env_key}-${app_key}-${app_key}-${vm}"
              }
            ]
          ]) : 
          # This has sub-applications (e.g., in production environment)
          flatten([
            for sub_app_key, sub_app in app : [
              for vm in sub_app : {
                vm = vm
                env_key = env_key
                app_key = app_key
                sub_app_key = sub_app_key
                vm_index = "${env_key}-${app_key}-${sub_app_key}-${vm}"
              }
            ]
          ])
      ])
    ])
  ]))
  
  # Set of all VM names
  all_vms = toset([for vm_data in local.all_vm_data : vm_data.vm])
  
  # Map of VM to its hierarchy tags
  unique_vm_data = {
    for vm_data in local.all_vm_data :
      vm_data.vm_index => {
        vm = vm_data.vm
        tenant = local.tenant_tag
        environment = vm_data.env_key
        application = vm_data.app_key
        sub_application = vm_data.sub_app_key != vm_data.app_key ? vm_data.sub_app_key : null
      }
  }
  
  # Emergency stuff, if any
  emergency = try(local.tenant_data.emergency, null)
  emergency_vms = flatten([
    for emergency_key, emergency_data in local.emergency : emergency_data
  ])
  emergency_vm_tags = {
    for vm in local.emergency_vms :
      vm => "emergency"
  }
}

# Get VM instances by display name
data "nsxt_policy_vm" "vms" {
  for_each = local.all_vms
  
  display_name = each.value
}

# Apply all hierarchy tags to VMs
resource "nsxt_policy_vm_tags" "hierarchy_tags" {
  for_each = local.unique_vm_data
  
  instance_id = data.nsxt_policy_vm.vms[each.value.vm].instance_id
  
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
    for_each = contains(local.emergency_vms, each.value.vm) ? [local.emergency_vm_tags[each.value.vm]] : []
    content {
      scope = "emergency"
      tag   = tag.value
    }
  }
} 