output "config" {
  value = merge(local.config, {
    roots = merge(try(local.config.roots, {}), {
      (var.state_key) = {
        rg = {
          name     = azurerm_resource_group.project_rg.name
          id       = azurerm_resource_group.project_rg.id
          location = azurerm_resource_group.project_rg.location
        }
        vault = {
          name = azurerm_key_vault.project_kv.name
          id   = azurerm_key_vault.project_kv.id
        }
        groups            = local.entra_scope_role_groups
        scope_role_groups = local.scope_role_groups
      }
    })
  })
}
