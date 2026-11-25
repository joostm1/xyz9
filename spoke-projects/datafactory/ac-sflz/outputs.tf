# same-project handoff: full living object with this root under roots[state_key]
output "config" {
  value = merge(local.config, {
    roots = merge(try(local.config.roots, {}), {
      (var.state_key) = {
        roles = {
          platform = {
            for role in local.config.scopes.platform.roles : "platform-${role}" => {
              object_id    = azuread_group.project_roles["platform-${role}"].object_id
              display_name = azuread_group.project_roles["platform-${role}"].display_name
            }
          }
          datasets = merge([
            for dataset_key, dataset in local.config.scopes.datasets : {
              for role in dataset.roles : "${dataset_key}-${role}" => {
                dataset_key  = dataset_key
                role         = role
                object_id    = azuread_group.project_roles["dataset-${dataset_key}-${role}"].object_id
                display_name = azuread_group.project_roles["dataset-${dataset_key}-${role}"].display_name
              }
            }
          ]...)
        }
        accounts = local.sflz_landing_zones
      }
    })
  })
  sensitive = true
}
