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
}

# Create environment groups
resource "nsxt_policy_group" "environment_groups" {
  for_each = local.environments
  
  display_name = each.key
  description  = "Group for environment ${each.key}"
  
  criteria {
    condition {
      key         = "Tag"
      member_type = "VirtualMachine"
      operator    = "EQUALS"
      value       = "${each.key}"
    }
  }
}

# Create application groups
resource "nsxt_policy_group" "application_groups" {
  for_each = {
    for app in local.applications : app.app_key => app
  }
  
  display_name = each.key
  description  = "Group for application ${each.key}"
  
  criteria {
    condition {
      key         = "Tag"
      member_type = "VirtualMachine"
      operator    = "EQUALS"
      value       = "${each.key}"
    }
  }
}

# Create sub-application groups
resource "nsxt_policy_group" "sub_application_groups" {
  for_each = {
    for sub_app in flatten([
      for app in local.applications : [
        for sub in app.sub_apps : {
          key = sub.sub_app_key
          env = sub.env_key
          app = sub.app_key
        }
      ]
    ]) : sub_app.key => sub_app
  }
  
  display_name = each.key
  description  = "Group for sub-application ${each.key}"
  
  criteria {
    condition {
      key         = "Tag"
      member_type = "VirtualMachine"
      operator    = "EQUALS"
      value       = "${each.key}"
    }
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
} 