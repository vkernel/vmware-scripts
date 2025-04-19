# Get VM instances by name
data "nsxt_policy_vm" "vms" {
  for_each = local.vms_with_tags
  
  display_name = each.key
}

# Assign tags to VMs
resource "nsxt_policy_vm_tags" "vm_tags" {
  for_each = local.vms_with_tags
  
  instance_id = data.nsxt_policy_vm.vms[each.key].instance_id
  
  tag {
    scope = "application"
    tag   = "${each.value.tenant}-${each.value.application}"
  }
  
  dynamic "tag" {
    for_each = each.value.environment != "" ? [each.value.environment] : []
    content {
      scope = "environment"
      tag   = tag.value
    }
  }
  
  lifecycle {
    create_before_destroy = true
  }
} 