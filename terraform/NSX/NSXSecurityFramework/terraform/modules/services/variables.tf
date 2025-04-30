variable "authorized_flows" {
  description = "Parsed authorized flows from YAML file"
  type        = any
}

variable "tenant_id" {
  description = "ID of the tenant (e.g., wld09)"
  type        = string
} 