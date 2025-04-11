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

# Local variables for CSV data processing
locals {
  # Parse VM data from CSV
  vm_csv_data = csvdecode(file("${path.module}/src/vmsForFolder_Name.csv"))
  
  # Create unique tenant-application pairs
  tenant_app_pairs = distinct([
    for vm in local.vm_csv_data : 
    "${vm.Tenant}-${vm.Application}" if vm.Tenant != "" && vm.Application != ""
  ])
  
  # Create unique environments
  environments = distinct([
    for vm in local.vm_csv_data : 
    vm.Environment if vm.Environment != ""
  ])
  
  # Create a map of VMs with their tags
  vms_with_tags = {
    for vm in local.vm_csv_data :
    vm.Name => {
      tenant      = vm.Tenant
      environment = vm.Environment
      application = vm.Application
    } if vm.Name != "" && vm.Tenant != ""
  }
  
  # Parse flows from CSV
  flows_csv_data = csvdecode(file("${path.module}/src/flows.csv"))
} 