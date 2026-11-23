output "config" {
  value = merge(local.config, {
    roots = merge(try(local.config.roots, {}), {
      (var.state_key) = {
        hubs = {
          for loc in keys(local.config.hubs) :
          loc => module.datacenter_hub[loc].config
        }
        mesh_members = module.mesh_members.members
      }
    })
  })
}
