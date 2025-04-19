# Create application groups based on tenant-application tags
resource "nsxt_policy_group" "app_groups" {
  for_each = {
    for pair in local.tenant_app_pairs :
    pair => {
      tenant      = split("-", pair)[0]
      application = split("-", pair)[1]
    }
  }
  
  display_name = "app-${local.tenant}-${each.value.application}"
  description  = "Group for ${local.tenant} ${each.value.application} application"
  domain       = var.domain_id
  
  criteria {
    condition {
      key         = "Tag"
      member_type = "VirtualMachine"
      operator    = "EQUALS"
      value       = each.key
    }
  }
  
  lifecycle {
    create_before_destroy = true
  }
}

# Create environment groups
resource "nsxt_policy_group" "environment_groups" {
  for_each = toset(local.environments)
  
  display_name = "env-${local.tenant}-${each.key}"
  description  = "Group for ${each.key} environment"
  domain       = var.domain_id
  
  criteria {
    condition {
      key         = "Tag"
      member_type = "VirtualMachine"
      operator    = "EQUALS"
      value       = each.key
    }
  }
  
  lifecycle {
    create_before_destroy = true
  }
}

# Create groups for external entities (DNS, Jumphost, NTP, etc.) is now in external_groups.tf 