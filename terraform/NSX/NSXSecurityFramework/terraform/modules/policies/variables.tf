variable "tenant_id" {
  description = "ID of the tenant (e.g., wld09)"
  type        = string
}

variable "authorized_flows" {
  description = "Parsed authorized flows from YAML file"
  type        = any
}

variable "groups" {
  description = "Map of group IDs for reference in policies"
  type = object({
    tenant_group_id         = string
    environment_groups      = map(string)
    application_groups      = map(string)
    sub_application_groups  = map(string)
    external_service_groups = map(string)
    emergency_groups        = map(string)
  })
}

variable "services" {
  description = "Map of service definitions for reference in policies"
  type        = map(any)
} 