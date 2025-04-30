terraform {
  required_providers {
    nsxt = {
      source = "vmware/nsxt"
    }
  }
}

locals {
  tenant_key = var.tenant_id
  tenant_data = var.authorized_flows[local.tenant_key]
  
  # Extract unique service definitions from application policies
  service_definitions = distinct([
    for rule in try(local.tenant_data.application_policy, []) : {
      protocol = rule.protocol
      ports    = rule.ports
    }
  ])
}

# Create NSX services for each unique protocol and port combination
resource "nsxt_policy_service" "service" {
  for_each = {
    for idx, service in local.service_definitions : 
      "${service.protocol}_${join("_", [for port in service.ports : tostring(port)])}" => service
  }
  
  display_name = "svc-${local.tenant_key}-${each.key}"
  description  = "Service for ${each.key}"
  
  dynamic "l4_port_set_entry" {
    for_each = each.value.protocol == "tcp" || each.value.protocol == "udp" ? [each.value] : []
    content {
      display_name      = "port-${each.key}"
      protocol          = upper(each.value.protocol)
      destination_ports = [for port in each.value.ports : tostring(port)]
    }
  }
  
  dynamic "icmp_entry" {
    for_each = each.value.protocol == "icmp" ? [each.value] : []
    content {
      display_name = "icmp-${each.key}"
      protocol     = "ICMPv4"
    }
  }
} 