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
  # Parse VM data from YAML
  vm_yaml_data = yamldecode(file("${path.module}/src/VMs.yaml"))
  
  # Extract tenant from the YAML (only one tenant - "wld09" in the example)
  tenant = keys(local.vm_yaml_data)[0]
  
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
  
  # Parse flows from CSV
  flows_csv_data = csvdecode(file("${path.module}/src/flows.csv"))
} 