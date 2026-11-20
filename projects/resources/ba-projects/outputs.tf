# Root-module handoff: continue merge chain; nest this root under roots[var.state_key]
output "config" {
  value = merge(local.config, {
    roots = merge(try(local.config.roots, {}), {
      (var.state_key) = {
        projects = keys(local.projects)
      }
    })
  })
}
