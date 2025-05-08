terraform {
  required_providers {
    nsxt = {
      source  = "vmware/nsxt"
      version = "~> 3.4.0"
    }
  }
  required_version = ">= 1.0.0"
}

# Configure the NSX provider
provider "nsxt" {
  host                  = var.nsx_manager_host
  username              = var.nsx_username
  password              = var.nsx_password
  allow_unverified_ssl  = true
  max_retries           = 10
  retry_min_delay       = 500
  retry_max_delay       = 5000
  retry_on_status_codes = [429]
}

# Load YAML files
locals {
  # Determine which tenant YAML files to use based on the tenant_id
  inventory_file = var.inventory_file != "" ? var.inventory_file : "./tenants/${var.tenant_id}/inventory.yaml"
  authorized_flows_file = var.authorized_flows_file != "" ? var.authorized_flows_file : "./tenants/${var.tenant_id}/authorized-flows.yaml"
  
  # Parse YAML files
  inventory = yamldecode(file(local.inventory_file))
  authorized_flows = yamldecode(file(local.authorized_flows_file))
}

# Create tags
module "tags" {
  source = "./modules/tags"
  
  tenant_id = var.tenant_id
  inventory = local.inventory

  providers = {
    nsxt = nsxt
  }
}

# Create groups
module "groups" {
  source = "./modules/groups"
  
  tenant_id  = var.tenant_id
  tenant_tag = module.tags.tenant_tag
  inventory  = local.inventory
  
  depends_on = [module.tags]
  
  providers = {
    nsxt = nsxt
  }
}

# Create services
module "services" {
  source = "./modules/services"
  
  tenant_id       = var.tenant_id
  authorized_flows = local.authorized_flows
  
  depends_on = [module.groups]
  
  providers = {
    nsxt = nsxt
  }
}

# Create policies
module "policies" {
  source = "./modules/policies"
  
  tenant_id       = var.tenant_id
  authorized_flows = local.authorized_flows
  
  groups = {
    tenant_group_id         = module.groups.tenant_group_id
    environment_groups      = module.groups.environment_groups
    application_groups      = module.groups.application_groups
    sub_application_groups  = module.groups.sub_application_groups
    external_service_groups = module.groups.external_service_groups
    emergency_groups        = module.groups.emergency_groups
  }
  
  services = module.services.services
  
  depends_on = [module.services]
  
  providers = {
    nsxt = nsxt
  }
} 