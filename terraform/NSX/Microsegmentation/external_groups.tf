# Create external IP address groups based on the External section in VMs.yaml
# Create NSX groups for external IP addresses
resource "nsxt_policy_group" "external_groups" {
  for_each = local.external_entries
  
  display_name = "ext-${local.tenant}-${each.key}"
  description  = "External group for ${each.key}"
  domain       = var.domain_id
  criteria {
    ipaddress_expression {
      ip_addresses = each.value
    }
  }
  
  lifecycle {
    create_before_destroy = true
  }
}

# Output the external groups created
output "external_groups_created" {
  description = "List of external IP address groups created"
  value       = [for group in nsxt_policy_group.external_groups : group.display_name]
} 