# Create application-specific security policies
resource "nsxt_policy_security_policy" "application_policies" {
  for_each = {
    for pair in local.tenant_app_pairs :
    pair => {
      tenant      = split("-", pair)[0]
      application = split("-", pair)[1]
    }
  }
  
  display_name    = "Policy-${each.value.tenant}-${each.value.application}"
  description     = "Security policy for ${each.value.tenant} ${each.value.application} application"
  domain          = var.domain_id
  category        = "Application"
  sequence_number = 8
  
  # Process the flows to create firewall rules specific to this application
  dynamic "rule" {
    for_each = {
      for idx, flow in local.flows_csv_data :
      idx => {
        name             = flow.name
        source_vm        = flow["Source VM"]
        destination_vm   = flow["Destination VM"]
        protocol         = flow.Protocol
        port             = split(":", flow["Port Display"])[1]
        action           = flow["firewall action"]
      } if contains(
        # Filter flows where either source or destination is part of this application
        [
          for vm in local.vm_csv_data : 
          vm.Name if (vm.Name == flow["Source VM"] || vm.Name == flow["Destination VM"]) && 
                     "${vm.Tenant}-${vm.Application}" == each.key
        ],
        flow["Source VM"]
      ) || contains(
        [
          for vm in local.vm_csv_data : 
          vm.Name if (vm.Name == flow["Source VM"] || vm.Name == flow["Destination VM"]) && 
                     "${vm.Tenant}-${vm.Application}" == each.key
        ],
        flow["Destination VM"]
      )
    }
    
    content {
      display_name       = rule.value.name
      source_groups      = [for vm in [rule.value.source_vm] : 
                           nsxt_policy_group.app_groups[
                             for pair in local.tenant_app_pairs : pair if contains(
                               [for data in local.vm_csv_data : data.Name if data.Name == vm && 
                                 "${data.Tenant}-${data.Application}" == pair
                               ], vm
                             )
                           ][0].path if can(
                             nsxt_policy_group.app_groups[
                               for pair in local.tenant_app_pairs : pair if contains(
                                 [for data in local.vm_csv_data : data.Name if data.Name == vm && 
                                   "${data.Tenant}-${data.Application}" == pair
                                 ], vm
                               )
                             ][0].path
                           )]
      destination_groups = [for vm in [rule.value.destination_vm] : 
                           nsxt_policy_group.app_groups[
                             for pair in local.tenant_app_pairs : pair if contains(
                               [for data in local.vm_csv_data : data.Name if data.Name == vm && 
                                 "${data.Tenant}-${data.Application}" == pair
                               ], vm
                             )
                           ][0].path if can(
                             nsxt_policy_group.app_groups[
                               for pair in local.tenant_app_pairs : pair if contains(
                                 [for data in local.vm_csv_data : data.Name if data.Name == vm && 
                                   "${data.Tenant}-${data.Application}" == pair
                                 ], vm
                               )
                             ][0].path
                           )]
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
    for flow in local.flows_csv_data :
    "${flow.Protocol}-${split(":", flow["Port Display"])[1]}" => {
      protocol = flow.Protocol
      port     = split(":", flow["Port Display"])[1]
    }
  }
  
  display_name = "${each.value.protocol}-${each.value.port}"
  description  = "Service for ${each.value.protocol} port ${each.value.port}"
  
  dynamic "l4_port_set_entry" {
    for_each = each.value.protocol == "TCP" || each.value.protocol == "UDP" ? [1] : []
    content {
      display_name      = "${each.value.protocol}-${each.value.port}"
      protocol          = each.value.protocol
      destination_ports = [each.value.port]
    }
  }
  
  dynamic "icmp_entry" {
    for_each = each.value.protocol == "ICMP" ? [1] : []
    content {
      display_name = "ICMP"
      icmp_type    = "ICMPv4"
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