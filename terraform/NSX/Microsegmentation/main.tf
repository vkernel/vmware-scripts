terraform {
  required_providers {
    nsxt = {
      source  = "vmware/nsxt"
      version = "~> 3.4.0"
    }
  }
  required_version = ">= 1.0.0"
}

provider "nsxt" {
  host                 = var.nsx_manager
  username             = var.nsx_username
  password             = var.nsx_password
  allow_unverified_ssl = true
  max_retries          = 10
  retry_min_delay      = 500
  retry_max_delay      = 5000
}

# Local variables for YAML data processing
locals {
  # Parse VM data from YAML and exclude external key
  vm_yaml_data = {
    for tenant, tenant_data in yamldecode(file("${path.module}/src/VMs.yaml")) : tenant => {
      for k, v in tenant_data : k => v if k != "External"
    }
  }
  # Extract tenant from the YAML (only one tenant - "wld09" in the example)
  tenant = keys(local.vm_yaml_data)[0]
  
  # Extract allowed communications between environments
  allowed_communications = try(local.vm_yaml_data[local.tenant].allowed_communications, {})
  
  # Create a flattened map of environments and application tiers (excluding allowed_communications)
  env_apps = {
    for k, v in local.vm_yaml_data[local.tenant] : 
    k => v if k != "allowed_communications"
  }
  
  # Create a flat map of VMs with their metadata
  vms_with_tags = merge([
    for env_name, env_data in local.env_apps : 
      merge([
        for app_name, vms in env_data : 
          { for vm_name in vms : 
            vm_name => {
              tenant      = local.tenant
              environment = env_name
              application = app_name
              name        = vm_name
            }
          }
      ]...)
  ]...)
  
  # Create a list of VM objects compatible with the original csv format
  vm_csv_data = [
    for vm_name, vm_data in local.vms_with_tags : {
      Name        = vm_name
      Tenant      = vm_data.tenant
      Environment = vm_data.environment
      Application = vm_data.application
    }
  ]
  
  # Create unique tenant-application pairs
  tenant_app_pairs = distinct([
    for vm_name, vm_data in local.vms_with_tags : 
    "${vm_data.tenant}-${vm_data.application}"
  ])
  
  # Create unique environments
  environments = distinct([
    for vm_name, vm_data in local.vms_with_tags : 
    vm_data.environment
  ])
  
  # Create environment pairs that are allowed to communicate (handling empty arrays)
  allowed_env_pairs = flatten([
    for source_env, target_envs in local.allowed_communications : [
      for target_env in coalesce(target_envs, []) : {
        source = source_env
        target = target_env
      } if target_env != null
    ]
  ])
  
  # Create a map to easily check if communication is allowed between environments
  allowed_env_map = {
    for pair in local.allowed_env_pairs : "${pair.source}-${pair.target}" => true
  }
  
  # Parse flows from CSV
  flows_csv_data = csvdecode(file("${path.module}/src/flows.csv"))
  
  # Process the CSV data to identify unique flow combinations
  unique_flow_combinations = distinct([
    for flow in local.flows_csv_data :
    join(":", [
      try(
        [for vm in local.vm_csv_data : "${vm.Tenant}-${vm.Application}" if vm.Name == flow["Source VM"]][0],
        "External"
      ),
      try(
        [for vm in local.vm_csv_data : "${vm.Tenant}-${vm.Application}" if vm.Name == flow["Destination VM"]][0],
        "External"
      ),
      flow.Protocol,
      flow["Port Display"]
    ]) if flow["firewall action"] == "ALLOW"
  ])
  
  # Create the unique firewall rules based on the unique combinations
  unique_firewall_rules = {
    for combination in local.unique_flow_combinations :
    combination => {
      source_app     = split(":", combination)[0]
      dest_app       = split(":", combination)[1]
      protocol       = split(":", combination)[2]
      port           = split(":", combination)[3]
    }
  }
} 