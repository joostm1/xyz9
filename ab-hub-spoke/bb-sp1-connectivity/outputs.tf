output "config" {
  value = merge(local.config, {
    roots = merge(try(local.config.roots, {}), {
      (var.state_key) = {
        offices = {
          for name in keys(local.offices) :
          name => module.office[name].config
        }
      }
    })
  })
}
