variable "nsx_manager_host" {
  description = "The FQDN or IP of the NSX Manager"
  type        = string
}

variable "nsx_username" {
  description = "NSX username with permissions to manage objects"
  type        = string
}

variable "nsx_password" {
  description = "NSX password for the service account"
  type        = string
  sensitive   = true
}

variable "tenant_id" {
  description = "ID of the tenant to configure (e.g., wld09 or wld10)"
  type        = string
}

variable "inventory_file" {
  description = "Path to the tenant inventory YAML file"
  type        = string
  default     = ""
}

variable "authorized_flows_file" {
  description = "Path to the tenant authorized flows YAML file"
  type        = string
  default     = ""
} 