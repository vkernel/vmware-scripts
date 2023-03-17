locals {
  ipsec_vpn_tunnels = {
    to_tenant_1 = {
      ipsec_vpn_description = "IPSEC VPN tunnel 1 - created with Terraform"
      ipsec_vpn_pre_shared_key = "Supersecretpassword"
      ipsec_vpn_local_endpoint_ip_address = "221.201.95.227"
      ipsec_vpn_local_endpoint_networks = "192.168.12.0/24"
      ipsec_vpn_remote_endpoint_ip_address = "87.227.53.36"
      ipsec_vpn_remote_endpoint_networks = "87.227.53.37/32"
      ipsec_vpn_ike_version = "IKE_V2"
      ipsec_vpn_ike_encryption = "AES_256"
      ipsec_vpn_ike_digest = "SHA2_256"
      ipsec_vpn_ike_diffie_hellman_group = "GROUP14"
      ipsec_vpn_ike_association_life_time = 28800
      ipsec_vpn_tunnel_enable_perfect_forward_secrecy = "true"
      ipsec_vpn_tunnel_defragmentation_policy = "COPY"
      ipsec_vpn_tunnel_encryption = "AES_256"
      ipsec_vpn_tunnel_digest = "SHA2_256"
      ipsec_vpn_tunnel_diffie_hellman_group = "GROUP14"
      ipsec_vpn_tunnel_association_life_time = 3600
      ipsec_vpn_dpd_probe_interval = "30"
    }
    to_tenant_2 = {
      ipsec_vpn_description = "IPSEC VPN tunnel 2 - created with Terraform"
      ipsec_vpn_pre_shared_key = "Supersecretpassword"
      ipsec_vpn_local_endpoint_ip_address = "176.5.147.17"
      ipsec_vpn_local_endpoint_networks = "176.5.147.18/32"
      ipsec_vpn_remote_endpoint_ip_address = "222.7.191.76"
      ipsec_vpn_remote_endpoint_networks = "10.0.11.0/24"
      ipsec_vpn_ike_version = "IKE_V2"
      ipsec_vpn_ike_encryption = "AES_256"
      ipsec_vpn_ike_digest = "SHA2_256"
      ipsec_vpn_ike_diffie_hellman_group = "GROUP14"
      ipsec_vpn_ike_association_life_time = 28800
      ipsec_vpn_tunnel_enable_perfect_forward_secrecy = "true"
      ipsec_vpn_tunnel_defragmentation_policy = "COPY"
      ipsec_vpn_tunnel_encryption = "AES_256"
      ipsec_vpn_tunnel_digest = "SHA2_256"
      ipsec_vpn_tunnel_diffie_hellman_group = "GROUP14"
      ipsec_vpn_tunnel_association_life_time = 3600
      ipsec_vpn_dpd_probe_interval = "30"
    }
  }
}

