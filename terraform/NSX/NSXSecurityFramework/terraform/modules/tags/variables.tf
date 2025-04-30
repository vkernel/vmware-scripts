variable "tenant_id" {
  description = "ID of the tenant (e.g., wld09)"
  type        = string
}

variable "inventory" {
  description = "Parsed tenant inventory from YAML file"
  type        = any
} 