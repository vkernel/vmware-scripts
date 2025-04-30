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

  # Process allowed and blocked environment communications
  allowed_env_rules = flatten([
    for src_env, dst_envs in try(local.environment_policy.allowed_communications, {}) : [
      for dst_env in dst_envs : {
        name        = "allow-${src_env}-to-${dst_env}"
        source      = src_env
        destination = dst_env
        action      = "ALLOW"
      }
    ]
  ])

  blocked_env_rules = flatten([
    for src_env, dst_envs in try(local.environment_policy.blocked_communications, {}) : [
      for dst_env in dst_envs : {
        name        = "block-${src_env}-to-${dst_env}"
        source      = src_env
        destination = dst_env
        action      = "DROP"
      }
    ]
  ])

  # Combine environment rules
  environment_rules = concat(local.allowed_env_rules, local.blocked_env_rules)

  # Process application policy rules
  application_rules = [
    for idx, rule in local.application_policy : {
      name        = "app-rule-${idx + 1}"
      sources     = rule.source
      destinations = rule.destination
      services    = "${rule.protocol}_${join("_", [for port in rule.ports : tostring(port)])}"
      protocol    = rule.protocol
      ports       = rule.ports
      action      = "ALLOW"
    }
  ]
}

# Create environment security policy
resource "nsxt_policy_security_policy" "environment_policy" {
  count = length(local.environment_rules) > 0 ? 1 : 0

  display_name = "env-${local.tenant_key}-policy"
  description  = "Environment security policy for tenant ${local.tenant_key}"
  category     = "Environment"
  locked       = false
  stateful     = true

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
}

# Create application security policy
resource "nsxt_policy_security_policy" "application_policy" {
  count = length(local.application_rules) > 0 ? 1 : 0

  display_name = "app-${local.tenant_key}-policy"
  description  = "Application security policy for tenant ${local.tenant_key}"
  category     = "Application"
  locked       = false
  stateful     = true

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
          startswith(src, "app-") ? (
            contains(keys(var.groups.sub_application_groups), src) ? 
              var.groups.sub_application_groups[src] : 
              var.groups.application_groups[src]
          ) : 
          startswith(src, "env-") ? var.groups.environment_groups[src] : 
          startswith(src, "ext-") ? var.groups.external_service_groups[src] :
          startswith(src, "ten-") ? var.groups.tenant_group_id : ""
        ]
      ])
      
      # Handle destination groups with appropriate lookup based on format
      destination_groups = flatten([
        for dst in (
          # Try to treat as list first, if not possible use as a single string
          try(tolist(rule.value.destinations), [rule.value.destinations])
        ) : [
          startswith(dst, "app-") ? (
            contains(keys(var.groups.sub_application_groups), dst) ? 
              var.groups.sub_application_groups[dst] : 
              var.groups.application_groups[dst]
          ) : 
          startswith(dst, "env-") ? var.groups.environment_groups[dst] : 
          startswith(dst, "ext-") ? var.groups.external_service_groups[dst] :
          startswith(dst, "ten-") ? var.groups.tenant_group_id : ""
        ]
      ])
      
      services         = [var.services[rule.value.services].path]
      action           = rule.value.action
      logged           = true
    }
  }
  
  depends_on = [nsxt_policy_security_policy.environment_policy]
} 
