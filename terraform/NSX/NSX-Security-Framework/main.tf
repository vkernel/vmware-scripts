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

# Load YAML files for all tenants
locals {
  # Create a map of tenant configurations
  tenant_configs = {
    for tenant_id in var.tenants : tenant_id => {
      inventory_file = var.inventory_file != "" ? var.inventory_file : "./tenants/${tenant_id}/inventory.yaml"
      authorized_flows_file = var.authorized_flows_file != "" ? var.authorized_flows_file : "./tenants/${tenant_id}/authorized-flows.yaml"
      inventory = yamldecode(file(var.inventory_file != "" ? var.inventory_file : "./tenants/${tenant_id}/inventory.yaml"))
      authorized_flows = yamldecode(file(var.authorized_flows_file != "" ? var.authorized_flows_file : "./tenants/${tenant_id}/authorized-flows.yaml"))
    }
  }
}

# Create tags for each tenant
module "tags" {
  source = "./modules/tags"
  
  for_each = local.tenant_configs
  
  tenant_id = each.key
  inventory = each.value.inventory

  providers = {
    nsxt = nsxt
  }
}

# Create groups for each tenant
module "groups" {
  source = "./modules/groups"
  
  for_each = local.tenant_configs
  
  tenant_id  = each.key
  tenant_tag = module.tags[each.key].tenant_tag
  inventory  = each.value.inventory
  
  depends_on = [module.tags]
  
  providers = {
    nsxt = nsxt
  }
}

# Create services for each tenant
module "services" {
  source = "./modules/services"
  
  for_each = local.tenant_configs
  
  tenant_id       = each.key
  authorized_flows = each.value.authorized_flows
  
  depends_on = [module.groups]
  
  providers = {
    nsxt = nsxt
  }
}

# Create policies for each tenant
module "policies" {
  source = "./modules/policies"
  
  for_each = local.tenant_configs
  
  tenant_id       = each.key
  authorized_flows = each.value.authorized_flows
  
  groups = {
    tenant_group_id         = module.groups[each.key].tenant_group_id
    environment_groups      = module.groups[each.key].environment_groups
    application_groups      = module.groups[each.key].application_groups
    sub_application_groups  = module.groups[each.key].sub_application_groups
    external_service_groups = module.groups[each.key].external_service_groups
    emergency_groups        = module.groups[each.key].emergency_groups
  }
  
  services = module.services[each.key].services
  
  depends_on = [module.services]
  
  providers = {
    nsxt = nsxt
  }
} 