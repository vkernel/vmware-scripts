# Declaring variables
variable "vcd_allow_unverified_ssl" {
    default = true
}
variable "vcd_url" {}
variable "vcd_org_name" {}
variable "vcd_org_vdc" {}
variable "vcd_vdc_group" {}
variable "vcd_edge_name" {}
variable "vcd_max_retry_timeout" {
    default = 60
}
variable "vcd_passwordstate_password_id" {}
variable "passwordstate_url" {}
variable "passwordstate_api_key" {}

terraform {
  required_providers {
    vcd = {
      source = "vmware/vcd"
      version = "3.8.2"
    }
  }
}

# Passwordstate - Retrieve vCD svc credentials based on Passwordstate PasswordID
data "http" "passwordstate_vcd_retrieve_password" {
  url = "${var.passwordstate_url}/api/passwords/${var.vcd_passwordstate_password_id}"
  # Optional request headers
  request_headers = {
    APIKey = var.passwordstate_api_key
  }
}

# Passwordstate - Retrieve IPSec VPN Pre-Shared key based on Passwordstate PasswordID
data "http" "passwordstate_ipsec_vpn_retrieve_password" {
  for_each = local.ipsec_vpn_tunnels
  url = "${var.passwordstate_url}/api/passwords/${each.value.ipsec_vpn_password_id}"
  # Optional request headers
  request_headers = {
    APIKey = var.passwordstate_api_key
  }
}

# Connection for the VMware Cloud Director Provider
provider "vcd" {
  url      = var.vcd_url
  user     = jsondecode(data.http.passwordstate_vcd_retrieve_password.response_body)[index(jsondecode(data.http.passwordstate_vcd_retrieve_password.response_body).*.PasswordID, var.vcd_passwordstate_password_id)].UserName
  password = jsondecode(data.http.passwordstate_vcd_retrieve_password.response_body)[index(jsondecode(data.http.passwordstate_vcd_retrieve_password.response_body).*.PasswordID, var.vcd_passwordstate_password_id)].Password
  org      = var.org_name
  vdc      = var.org_vdc

  max_retry_timeout    = "120"
  allow_unverified_ssl = "true"

  logging = "true"
}

# Get vDC group
data "vcd_vdc_group" "vdc_group" {
  org  = var.org_name
  name = var.org_vdc_group
}

# Get tenant NSX-T Edge based on vDC group
data "vcd_nsxt_edgegateway" "edge" {
  org      = var.org_name
  owner_id = data.vcd_vdc_group.vdc_group.id
  name     = var.org_edge_name
}

# Maintaining IPSec VPN tunnels
resource "vcd_nsxt_ipsec_vpn_tunnel" "tunnels" {
  org = var.org_name

  edge_gateway_id = data.vcd_nsxt_edgegateway.edge.id
  for_each = local.ipsec_vpn_tunnels
  name        = each.key
  description = each.value.ipsec_vpn_description

  pre_shared_key = jsondecode(data.http.passwordstate_ipsec_vpn_retrieve_password[each.key].response_body)[index(jsondecode(data.http.passwordstate_ipsec_vpn_retrieve_password[each.key].response_body).*.PasswordID, local.ipsec_vpn_tunnels[each.key].ipsec_vpn_password_id)].Password
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