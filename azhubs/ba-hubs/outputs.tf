output "config" {
  value = merge(local.config, {
    roots = merge(try(local.config.roots, {}), {
      (var.state_key) = {
        locations = {
          for loc in keys(local.config.locations) :
          loc => module.datacenter_hub[loc].config
        }
        mesh_members = module.mesh_members.members
      }
    })
  })
}
