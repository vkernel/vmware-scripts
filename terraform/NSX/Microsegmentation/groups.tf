# Create application groups based on tenant-application tags
resource "nsxt_policy_group" "app_groups" {
  for_each = {
    for pair in local.tenant_app_pairs :
    pair => {
      tenant      = split("-", pair)[0]
      application = split("-", pair)[1]
    }
  }
  
  display_name = "app-${each.value.tenant}-${each.value.application}"
  description  = "Group for ${each.value.tenant} ${each.value.application} application"
  domain       = var.domain_id
  
  criteria {
    condition {
      key         = "Tag"
      member_type = "VirtualMachine"
      operator    = "EQUALS"
      value       = each.key
      scope       = "application"
    }
  }
  
  lifecycle {
    create_before_destroy = true
  }
}

# Create environment groups
resource "nsxt_policy_group" "environment_groups" {
  for_each = toset(local.environments)
  
  display_name = "env-${each.key}"
  description  = "Group for ${each.key} environment"
  domain       = var.domain_id
  
  criteria {
    condition {
      key         = "Tag"
      member_type = "VirtualMachine"
      operator    = "EQUALS"
      value       = each.key
      scope       = "environment"
    }
  }
  
  lifecycle {
    create_before_destroy = true
  }
} 