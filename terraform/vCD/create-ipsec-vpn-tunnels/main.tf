# Declaring variables
variable "vcd_user" {}
variable "vcd_pass" {}
variable "vcd_allow_unverified_ssl" {
    default = false
}
variable "vcd_url" {}
variable "vcd_org_name" {}
variable "vcd_org_vdc" {}
variable "vcd_vdc_group" {}
variable "vcd_edge_name" {}
variable "vcd_max_retry_timeout" {
    default = 60
}

terraform {
  required_providers {
    vcd = {
      source = "vmware/vcd"
      version = "3.8.2"
    }
  }
}

# Connection for the VMware Cloud Director Provider
provider "vcd" {
  url      = var.vcd_url
  user     = var.vcd_user
  password = var.vcd_pass
  org      = var.vcd_org_name
  vdc      = var.vcd_org_vdc

  max_retry_timeout    = var.vcd_max_retry_timeout
  allow_unverified_ssl = var.vcd_allow_unverified_ssl

  logging = "true"
}

# Get VDC group
data "vcd_vdc_group" "vdc_group" {
  org  = var.vcd_org_name
  name = var.vcd_vdc_group
}

# Get tenant NSX-T Edge based on vDC group
data "vcd_nsxt_edgegateway" "edge" {
  org      = var.vcd_org_name
  owner_id = data.vcd_vdc_group.vdc_group.id
  name     = var.vcd_edge_name
}

# Maintaining IPSec VPN tunnels
resource "vcd_nsxt_ipsec_vpn_tunnel" "tunnel1" {
  org = var.vcd_org_name

  edge_gateway_id = data.vcd_nsxt_edgegateway.edge.id
  for_each = local.ipsec_vpn_tunnels
  name        = each.key
  description = each.value.ipsec_vpn_description

  pre_shared_key = each.value.ipsec_vpn_pre_shared_key
  local_ip_address = each.value.ipsec_vpn_local_endpoint_ip_address
  local_networks   = [each.value.ipsec_vpn_local_endpoint_networks]
  remote_ip_address = each.value.ipsec_vpn_remote_endpoint_ip_address
  remote_networks   = [each.value.ipsec_vpn_remote_endpoint_networks]

  security_profile_customization {
    ike_version               = each.value.ipsec_vpn_ike_version
    ike_encryption_algorithms = [each.value.ipsec_vpn_ike_encryption]
    ike_digest_algorithms     = [each.value.ipsec_vpn_ike_digest]
    ike_dh_groups             = [each.value.ipsec_vpn_ike_diffie_hellman_group]
    ike_sa_lifetime           = each.value.ipsec_vpn_ike_association_life_time

    tunnel_pfs_enabled           = each.value.ipsec_vpn_tunnel_enable_perfect_forward_secrecy
    tunnel_df_policy             = each.value.ipsec_vpn_tunnel_defragmentation_policy
    tunnel_encryption_algorithms = [each.value.ipsec_vpn_tunnel_encryption]
    tunnel_digest_algorithms     = [each.value.ipsec_vpn_tunnel_digest]
    tunnel_dh_groups             = [each.value.ipsec_vpn_tunnel_diffie_hellman_group]
    tunnel_sa_lifetime           = each.value.ipsec_vpn_tunnel_association_life_time

    dpd_probe_internal = each.value.ipsec_vpn_dpd_probe_interval
  }
}