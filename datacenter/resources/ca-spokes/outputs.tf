output "config" {
  value = merge(local.config, {
    roots = merge(try(local.config.roots, {}), {
      (var.state_key) = {
        locations = {
          for location in keys(local.hub_locations) : location => {
            spokes = {
              for spoke_project in local.spoke_projects :
              spoke_project.name => module.spoke["${location}-${spoke_project.name}"].config.spoke
              if spoke_project.hub_location == location
            }
          }
        }
      }
    })
  })
}
