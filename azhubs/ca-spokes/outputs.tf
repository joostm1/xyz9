output "config" {
  value = merge(local.config, {
    roots = merge(try(local.config.roots, {}), {
      (var.state_key) = {
        hubs = {
          for hub in keys(local.hubs) : hub => {
            spokes = {
              for spoke_project in local.spoke_projects :
              spoke_project.name => module.spoke["${hub}-${spoke_project.name}"].config.spoke
              if spoke_project.hub_location == hub
            }
          }
        }
      }
    })
  })
}
