# Create a single security policy for all applications
resource "nsxt_policy_security_policy" "application_policy" {
  display_name    = "${local.tenant}-Application Security Policy"
  description     = "Security policy for all applications"
  domain          = var.domain_id
  category        = "Application"
  sequence_number = 8
  
  # Process the flows to create firewall rules - using the deduplicated rules
  dynamic "rule" {
    for_each = local.unique_firewall_rules
    
    content {
      display_name       = "${rule.value.source_app} to ${rule.value.dest_app} [${rule.value.protocol}-${rule.value.port}]"
      description        = "Allow communication from ${rule.value.source_app} to ${rule.value.dest_app} on ${rule.value.protocol} port ${rule.value.port}"
      source_groups      = [
        try(
          # Try app_groups first for application tiers
          nsxt_policy_group.app_groups[rule.value.source_app].path,
          # Then try external_groups for external entities
          try(
            nsxt_policy_group.external_groups[rule.value.source_app].path,
            # Default to production environment if not found
            nsxt_policy_group.environment_groups["Production"].path
          )
        )
      ]
      destination_groups = [
        try(
          # Try app_groups first for application tiers
          nsxt_policy_group.app_groups[rule.value.dest_app].path,
          # Then try external_groups for external entities
          try(
            nsxt_policy_group.external_groups[rule.value.dest_app].path,
            # Default to production environment if not found
            nsxt_policy_group.environment_groups["Production"].path
          )
        )
      ]
      services           = [nsxt_policy_service.services["${rule.value.protocol}-${rule.value.port}"].path]
      action             = "ALLOW"  # Always ALLOW for these rules
      logged             = true
    }
  }
  
  # Final rule to deny all other application traffic
  rule {
    display_name = "Deny All Other Application Traffic"
    description  = "Deny all other traffic between applications"
    action       = "DROP"
    logged       = true
  }
  
  lifecycle {
    create_before_destroy = true
  }
}

# Create service entries for each protocol/port combination
resource "nsxt_policy_service" "services" {
  for_each = {
    for pair in distinct(flatten([
      for tenant, rules in local.allowed_flows_yaml : [
        for rule in rules : [
          for port in rule.ports : 
          "${upper(rule.protocol)}-${port}"
        ]
      ]
    ])) :
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
  description  = "Security policy to isolate environments based on allowed_communications"
  domain       = var.domain_id
  category     = "Environment"
  
  # Higher sequence number than application policies
  sequence_number = 10
  
  # Allow rules for explicitly permitted environment communications
  dynamic "rule" {
    for_each = local.allowed_env_pairs
    
    content {
      display_name       = "Allow ${rule.value.source} to ${rule.value.target}"
      description        = "Allow communication from ${rule.value.source} to ${rule.value.target} as specified in allowed_communications"
      source_groups      = [nsxt_policy_group.environment_groups[rule.value.source].path]
      destination_groups = [nsxt_policy_group.environment_groups[rule.value.target].path]
      action             = "ALLOW"
      logged             = true
    }
  }
  
  lifecycle {
    create_before_destroy = true
  }
} 