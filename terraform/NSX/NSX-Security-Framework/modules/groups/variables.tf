variable "tenant_id" {
  description = "ID of the tenant (e.g., wld09)"
  type        = string
}

variable "tenant_tag" {
  description = "The tenant tag for this deployment"
  type        = string
}

variable "inventory" {
  description = "Parsed tenant inventory from YAML file"
  type        = any
} 