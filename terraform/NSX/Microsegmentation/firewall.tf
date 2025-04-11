# Create a single security policy for all applications
resource "nsxt_policy_security_policy" "application_policy" {
  display_name    = "Application Security Policy"
  description     = "Security policy for all applications"
  domain          = var.domain_id
  category        = "Application"
  sequence_number = 8
  
  # Process the flows to create firewall rules
  dynamic "rule" {
    for_each = {
      for idx, flow in local.flows_csv_data :
      idx => {
        source_app      = try(
          [for vm in local.vm_csv_data : "${vm.Tenant}-${vm.Application}" if vm.Name == flow["Source VM"]][0],
          "External"
        )
        dest_app        = try(
          [for vm in local.vm_csv_data : "${vm.Tenant}-${vm.Application}" if vm.Name == flow["Destination VM"]][0],
          "External"
        )
        source_vm      = flow["Source VM"]
        destination_vm = flow["Destination VM"]
        protocol       = flow.Protocol
        port           = flow["Port Display"]
        action         = flow["firewall action"]
      }
    }
    
    content {
      display_name       = "${rule.value.source_app} to ${rule.value.dest_app} [${rule.value.protocol}-${rule.value.port}]"
      description        = "Allow communication from ${rule.value.source_app} to ${rule.value.dest_app} on ${rule.value.protocol} port ${rule.value.port}"
      source_groups      = [
        try(
          [for pair in local.tenant_app_pairs : 
            nsxt_policy_group.app_groups[pair].path
            if contains(
              [for data in local.vm_csv_data : data.Name 
                if data.Name == rule.value.source_vm && "${data.Tenant}-${data.Application}" == pair
              ],
              rule.value.source_vm
            )
          ][0],
          nsxt_policy_group.environment_groups["Production"].path
        )
      ]
      destination_groups = [
        try(
          [for pair in local.tenant_app_pairs : 
            nsxt_policy_group.app_groups[pair].path
            if contains(
              [for data in local.vm_csv_data : data.Name 
                if data.Name == rule.value.destination_vm && "${data.Tenant}-${data.Application}" == pair
              ],
              rule.value.destination_vm
            )
          ][0],
          nsxt_policy_group.environment_groups["Production"].path
        )
      ]
      services           = [nsxt_policy_service.services["${rule.value.protocol}-${rule.value.port}"].path]
      action             = rule.value.action
      logged             = true
    }
  }
  
  lifecycle {
    create_before_destroy = true
  }
}

# Create service entries for each protocol/port combination
resource "nsxt_policy_service" "services" {
  for_each = {
    for pair in distinct([
      for flow in local.flows_csv_data :
      "${flow.Protocol}-${flow["Port Display"]}"
    ]) :
    pair => {
      protocol = split("-", pair)[0]
      port     = split("-", pair)[1]
    }
  }
  
  display_name = each.key
  description  = "Service for ${each.value.protocol} port ${each.value.port}"
  
  dynamic "l4_port_set_entry" {
    for_each = each.value.protocol == "TCP" || each.value.protocol == "UDP" ? [1] : []
    content {
      display_name      = each.key
      protocol          = each.value.protocol
      destination_ports = [each.value.port]
    }
  }
  
  dynamic "icmp_entry" {
    for_each = each.value.protocol == "ICMP" ? [1] : []
    content {
      display_name = "ICMP"
      protocol    = "ICMPv4"
      icmp_type   = "ICMPv4"
    }
  }
  
  lifecycle {
    create_before_destroy = true
  }
}

# Create environment isolation policy
resource "nsxt_policy_security_policy" "environment_isolation" {
  display_name = "Environment Isolation Policy"
  description  = "Security policy to isolate OTAP environments"
  domain       = var.domain_id
  category     = "Environment"
  
  # Higher sequence number than application policies
  sequence_number = 10
  
  dynamic "rule" {
    for_each = {
      for idx, env1 in local.environments :
      idx => {
        env = env1
      }
    }
    
    content {
      display_name       = "Block ${rule.value.env} to other environments"
      source_groups      = [nsxt_policy_group.environment_groups[rule.value.env].path]
      destination_groups = [for env in local.environments : 
                           nsxt_policy_group.environment_groups[env].path if env != rule.value.env]
      action             = "REJECT"
      logged             = true
    }
  }
  
  # Default rule to allow intra-environment communication
  rule {
    display_name = "Allow same environment communication"
    action       = "ALLOW"
    logged       = true
  }
  
  lifecycle {
    create_before_destroy = true
  }
} 