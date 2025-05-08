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

  # Extract policy data
  environment_policy = try(local.tenant_data.environment_policy, {})
  application_policy = try(local.tenant_data.application_policy, [])
  emergency_policy = try(local.tenant_data.emergency_policy, [])

  # Process allowed and blocked environment communications
  allowed_env_rules = [
    for rule in try(local.environment_policy.allowed_communications, []) : {
      name        = try(rule.name, "allow-${rule.source}-to-${rule.destination}")
      source      = rule.source
      destination = rule.destination
      action      = "ALLOW"
    }
  ]

  blocked_env_rules = [
    for rule in try(local.environment_policy.blocked_communications, []) : {
      name        = try(rule.name, "block-${rule.source}-to-${rule.destination}")
      source      = rule.source
      destination = rule.destination
      action      = "DROP"
    }
  ]

  # Combine environment rules
  environment_rules = concat(local.allowed_env_rules, local.blocked_env_rules)

  # Process application policy rules
  application_rules = [
    for rule in local.application_policy : {
      name        = try(rule.name, "app-rule-${index(local.application_policy, rule) + 1}")
      sources     = rule.source
      destinations = rule.destination
      # Use services field if specified, otherwise construct from protocol/ports
      service_keys = try(rule.services, null) != null ? rule.services : ["${rule.protocol}_${join("_", [for port in rule.ports : tostring(port)])}"]
      action      = "ALLOW"
    }
  ]
  
  # Process emergency policy rules
  emergency_rules = [
    for rule in local.emergency_policy : {
      name        = try(rule.name, "emergency-rule-${index(local.emergency_policy, rule) + 1}")
      sources     = rule.source
      destinations = rule.destination
      action      = "ALLOW"
    }
  ]
}

# Create emergency security policy
resource "nsxt_policy_security_policy" "emergency_policy" {
  count = length(local.emergency_rules) > 0 ? 1 : 0

  display_name = "emergency-${local.tenant_key}-policy"
  description  = "Emergency security policy for tenant ${local.tenant_key}"
  category     = "Emergency"
  locked       = false
  stateful     = true
  sequence_number = 1  # Highest priority
  scope = [var.groups.tenant_group_id]

  dynamic "rule" {
    for_each = local.emergency_rules
    content {
      display_name       = rule.value.name
      
      # Handle source groups with appropriate lookup based on format
      source_groups = flatten([
        for src in (
          # Try to treat as list first, if not possible use as a single string
          try(tolist(rule.value.sources), [rule.value.sources])
        ) : [
          # Look up the group path based on the prefix
          startswith(src, "app-") ? (
            contains(keys(var.groups.sub_application_groups), src) ? 
              var.groups.sub_application_groups[src] : 
              var.groups.application_groups[src]
          ) : 
          startswith(src, "env-") ? var.groups.environment_groups[src] : 
          startswith(src, "ext-") ? var.groups.external_service_groups[src] :
          startswith(src, "ten-") ? var.groups.tenant_group_id :
          contains(keys(var.groups.emergency_groups), src) ? var.groups.emergency_groups[src] : ""
        ]
        if (
          (startswith(src, "app-") && (contains(keys(var.groups.sub_application_groups), src) || contains(keys(var.groups.application_groups), src))) ||
          (startswith(src, "env-") && contains(keys(var.groups.environment_groups), src)) ||
          (startswith(src, "ext-") && contains(keys(var.groups.external_service_groups), src)) ||
          (startswith(src, "ten-")) ||
          (contains(keys(var.groups.emergency_groups), src))
        )
      ])
      
      # Handle any as destination or specific destination
      destination_groups = contains(
        try(tolist(rule.value.destinations), [rule.value.destinations]),
        "any"
      ) ? [] : flatten([
        for dst in (
          # Try to treat as list first, if not possible use as a single string
          try(tolist(rule.value.destinations), [rule.value.destinations])
        ) : [
          # Look up the group path based on the prefix
          startswith(dst, "app-") ? (
            contains(keys(var.groups.sub_application_groups), dst) ? 
              var.groups.sub_application_groups[dst] : 
              var.groups.application_groups[dst]
          ) : 
          startswith(dst, "env-") ? var.groups.environment_groups[dst] : 
          startswith(dst, "ext-") ? var.groups.external_service_groups[dst] :
          startswith(dst, "ten-") ? var.groups.tenant_group_id :
          contains(keys(var.groups.emergency_groups), dst) ? var.groups.emergency_groups[dst] : ""
        ]
        if (
          (startswith(dst, "app-") && (contains(keys(var.groups.sub_application_groups), dst) || contains(keys(var.groups.application_groups), dst))) ||
          (startswith(dst, "env-") && contains(keys(var.groups.environment_groups), dst)) ||
          (startswith(dst, "ext-") && contains(keys(var.groups.external_service_groups), dst)) ||
          (startswith(dst, "ten-")) ||
          (contains(keys(var.groups.emergency_groups), dst))
        )
      ])
      
      action           = rule.value.action
      logged           = true
    }
  }
}

# Create environment security policy
resource "nsxt_policy_security_policy" "environment_policy" {
  count = length(local.environment_rules) > 0 ? 1 : 0

  display_name = "env-${local.tenant_key}-policy"
  description  = "Environment security policy for tenant ${local.tenant_key}"
  category     = "Environment"
  locked       = false
  stateful     = true
  sequence_number = 2  # Second priority after emergency
  scope = [var.groups.tenant_group_id]

  dynamic "rule" {
    for_each = local.environment_rules
    content {
      display_name       = rule.value.name
      source_groups      = [var.groups.environment_groups[rule.value.source]]
      destination_groups = [var.groups.environment_groups[rule.value.destination]]
      action             = rule.value.action
      logged             = true
    }
  }
  
  depends_on = [nsxt_policy_security_policy.emergency_policy]
}

# Create application security policy
resource "nsxt_policy_security_policy" "application_policy" {
  count = length(local.application_rules) > 0 ? 1 : 0

  display_name = "app-${local.tenant_key}-policy"
  description  = "Application security policy for tenant ${local.tenant_key}"
  category     = "Application"
  locked       = false
  stateful     = true
  sequence_number = 3  # Third priority after environment
  scope = [var.groups.tenant_group_id]

  dynamic "rule" {
    for_each = local.application_rules
    content {
      display_name       = rule.value.name
      
      # Handle source groups with appropriate lookup based on format
      source_groups = flatten([
        for src in (
          # Try to treat as list first, if not possible use as a single string
          try(tolist(rule.value.sources), [rule.value.sources])
        ) : [
          # Look up the group path based on the prefix
          startswith(src, "app-") ? (
            contains(keys(var.groups.sub_application_groups), src) ? 
              var.groups.sub_application_groups[src] : 
              var.groups.application_groups[src]
          ) : 
          startswith(src, "env-") ? var.groups.environment_groups[src] : 
          startswith(src, "ext-") ? var.groups.external_service_groups[src] :
          startswith(src, "ten-") ? var.groups.tenant_group_id :
          contains(keys(var.groups.emergency_groups), src) ? var.groups.emergency_groups[src] : ""
        ]
        if (
          (startswith(src, "app-") && (contains(keys(var.groups.sub_application_groups), src) || contains(keys(var.groups.application_groups), src))) ||
          (startswith(src, "env-") && contains(keys(var.groups.environment_groups), src)) ||
          (startswith(src, "ext-") && contains(keys(var.groups.external_service_groups), src)) ||
          (startswith(src, "ten-")) ||
          (contains(keys(var.groups.emergency_groups), src))
        )
      ])
      
      # Handle destination groups with appropriate lookup based on format
      destination_groups = flatten([
        for dst in (
          # Try to treat as list first, if not possible use as a single string
          try(tolist(rule.value.destinations), [rule.value.destinations])
        ) : [
          # Look up the group path based on the prefix
          startswith(dst, "app-") ? (
            contains(keys(var.groups.sub_application_groups), dst) ? 
              var.groups.sub_application_groups[dst] : 
              var.groups.application_groups[dst]
          ) : 
          startswith(dst, "env-") ? var.groups.environment_groups[dst] : 
          startswith(dst, "ext-") ? var.groups.external_service_groups[dst] :
          startswith(dst, "ten-") ? var.groups.tenant_group_id :
          contains(keys(var.groups.emergency_groups), dst) ? var.groups.emergency_groups[dst] : ""
        ]
        if (
          (startswith(dst, "app-") && (contains(keys(var.groups.sub_application_groups), dst) || contains(keys(var.groups.application_groups), dst))) ||
          (startswith(dst, "env-") && contains(keys(var.groups.environment_groups), dst)) ||
          (startswith(dst, "ext-") && contains(keys(var.groups.external_service_groups), dst)) ||
          (startswith(dst, "ten-")) ||
          (contains(keys(var.groups.emergency_groups), dst))
        )
      ])
      
      # Handle services - can be predefined or custom
      services = flatten([
        for service_key in rule.value.service_keys : [
          try(var.services[service_key].path, "")
        ]
        if try(var.services[service_key].path, "") != ""
      ])
      action           = rule.value.action
      logged           = true
    }
  }
  
  depends_on = [nsxt_policy_security_policy.environment_policy]
} 
