variable "nsx_manager" {
  description = "NSX manager IP address or hostname"
  type        = string
}

variable "nsx_username" {
  description = "NSX manager username"
  type        = string
}

variable "nsx_password" {
  description = "NSX manager password"
  type        = string
  sensitive   = true
}

variable "domain_id" {
  description = "NSX Policy domain ID"
  type        = string
  default     = "default"
}

variable "site_id" {
  description = "NSX Policy site ID"
  type        = string
  default     = "default"
} 