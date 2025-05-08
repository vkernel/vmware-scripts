output "services" {
  description = "Map of services created for this tenant"
  value = {
    for service_key, service in nsxt_policy_service.service : service_key => {
      id          = service.id
      display_name = service.display_name
      path        = service.path
    }
  }
} 