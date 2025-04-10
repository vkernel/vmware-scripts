# Create tenant-application tags
resource "nsxt_policy_tag" "tenant_app_tags" {
  for_each = toset(local.tenant_app_pairs)
  
  tag     = each.value
  scope   = "application"
  
  lifecycle {
    create_before_destroy = true
  }
}

# Create environment tags
resource "nsxt_policy_tag" "environment_tags" {
  for_each = toset(local.environments)
  
  tag     = each.value
  scope   = "environment"
  
  lifecycle {
    create_before_destroy = true
  }
} 