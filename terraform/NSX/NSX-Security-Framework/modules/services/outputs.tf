output "services" {
  description = "Map of services created for this tenant"
  value = merge(
    {
      for service_key, service in nsxt_policy_service.service : service_key => {
        id          = service.id
        display_name = service.display_name
        path        = service.path
      }
    },
    {
      for service_name, service in data.nsxt_policy_service.predefined_services : service_name => {
        id          = service.id
        display_name = service.display_name
        path        = service.path
      }
    }
  )
} 