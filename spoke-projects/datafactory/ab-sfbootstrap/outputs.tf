# same-project handoff: full living object with this root under roots[state_key]
output "config" {
  value = merge(local.config, {
    snowflake = merge(local.config.snowflake, {
      accounts = local.published_accounts
    })
    roots = merge(try(local.config.roots, {}), {
      (var.state_key) = {
        project_vault_id  = azurerm_key_vault.project.id
        project_vault_uri = azurerm_key_vault.project.vault_uri
        accounts          = local.published_accounts
      }
    })
  })
}
