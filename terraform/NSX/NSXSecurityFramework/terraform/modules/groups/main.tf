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
  tenant_tag = var.tenant_tag
  
  # Extract all environments
  environments = try(local.tenant_data.internal, {})
  
  # Extract external services
  external_services = try(local.tenant_data.external, {})
  
  # Extract emergency resources
  emergency_resources = try(local.tenant_data.emergency, {})
  
  # Flatten applications for easy access
  applications = flatten([
    for env_key, env_data in local.environments : [
      for app_key, app_data in env_data : {
        env_key = env_key
        app_key = app_key
        sub_apps = try(
          [
            for sub_app_key, sub_app_data in app_data : 
            {
              env_key = env_key
              app_key = app_key
              sub_app_key = sub_app_key
            }
            if can(sub_app_data[0]) && sub_app_key != app_key
          ], 
          []
        )
      }
    ]
  ])
  
  # Create a list of all unique environment keys
  environment_keys = keys(local.environments)
  
  # Create a list of all unique application keys
  application_keys = distinct([
    for app in local.applications : app.app_key
  ])
  
  # Create a list of all unique sub-application keys
  sub_application_keys = distinct(flatten([
    for app in local.applications : [
      for sub_app in app.sub_apps : sub_app.sub_app_key
    ]
  ]))
}

# Create tenant group
resource "nsxt_policy_group" "tenant_group" {
  display_name = local.tenant_tag
  description  = "Group for all VMs in tenant ${local.tenant_key}"
  
  criteria {
    condition {
      key         = "Tag"
      member_type = "VirtualMachine"
      operator    = "EQUALS"
      value       = "${local.tenant_tag}"
    }
  }

  tag {
    scope = "tenant"
    tag   = local.tenant_tag
  }
}

# Create environment groups
resource "nsxt_policy_group" "environment_groups" {
  for_each = toset(local.environment_keys)
  
  display_name = each.value
  description  = "Group for environment ${each.value}"
  
  criteria {
    condition {
      key         = "Tag"
      member_type = "VirtualMachine"
      operator    = "EQUALS"
      value       = "${each.value}"
    }
  }

  tag {
    scope = "environment"
    tag   = each.value
  }
}

# Create application groups
resource "nsxt_policy_group" "application_groups" {
  for_each = toset(local.application_keys)
  
  display_name = each.value
  description  = "Group for application ${each.value}"
  
  criteria {
    condition {
      key         = "Tag"
      member_type = "VirtualMachine"
      operator    = "EQUALS"
      value       = "${each.value}"
    }
  }

  tag {
    scope = "application"
    tag   = each.value
  }
}

# Create sub-application groups
resource "nsxt_policy_group" "sub_application_groups" {
  for_each = toset(local.sub_application_keys)
  
  display_name = each.value
  description  = "Group for sub-application ${each.value}"
  
  criteria {
    condition {
      key         = "Tag"
      member_type = "VirtualMachine"
      operator    = "EQUALS"
      value       = "${each.value}"
    }
  }

  tag {
    scope = "sub-application"
    tag   = each.value
  }
}

# Create external service groups
resource "nsxt_policy_group" "external_service_groups" {
  for_each = local.external_services
  
  display_name = each.key
  description  = "Group for external service ${each.key}"
  
  dynamic "criteria" {
    for_each = each.value
    content {
      ipaddress_expression {
        ip_addresses = [criteria.value]
      }
    }
  }

  tag {
    scope = "external"
    tag   = each.key
  }
}

# Create emergency groups
resource "nsxt_policy_group" "emergency_groups" {
  for_each = local.emergency_resources
  
  display_name = each.key
  description  = "Group for emergency access ${each.key}"
  
  criteria {
    condition {
      key         = "Tag"
      member_type = "VirtualMachine"
      operator    = "EQUALS"
      value       = "${each.key}"
    }
  }

  tag {
    scope = "emergency"
    tag   = each.key
  }
} 