terraform {
  required_providers {
    nsxt = {
      source = "vmware/nsxt"
    }
  }
}

# Data source for predefined NSX services
data "nsxt_policy_service" "predefined_services" {
  for_each = toset(local.predefined_service_names)
  display_name = each.value
}

locals {
  tenant_key = var.tenant_id
  tenant_data = var.authorized_flows[local.tenant_key]
  
  # Extract all predefined service names from application policies
  predefined_service_names = distinct(flatten([
    for rule in try(local.tenant_data.application_policy, []) : 
      try(rule.services, [])
  ]))
  
  # Extract unique custom service definitions from application policies
  service_definitions = distinct(flatten([
    # Process rules that have only protocol and ports (no services)
    [
      for rule in try(local.tenant_data.application_policy, []) : {
        protocol = rule.protocol
        ports    = rule.ports
      }
      if try(rule.protocol, null) != null && try(rule.ports, null) != null && 
         try(rule.services, null) == null
    ],
    # Process rules that have both services and protocol/ports 
    [
      for rule in try(local.tenant_data.application_policy, []) : {
        protocol = rule.protocol
        ports    = rule.ports
      }
      if try(rule.protocol, null) != null && try(rule.ports, null) != null && 
         try(rule.services, null) != null
    ]
  ]))
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