# same-project handoff: full living object with this root under roots[state_key]
output "config" {
  value = merge(local.config, {
    roots = merge(try(local.config.roots, {}), {
      (var.state_key) = {
        project_vault_id  = azurerm_key_vault.project.id
        project_vault_uri = azurerm_key_vault.project.vault_uri
        scim = {
          service_user     = snowflake_service_user.scim.name
          provisioner_role = snowflake_account_role.scim_provisioner.name
          pat_secret_name  = azurerm_key_vault_secret.scim_pat.name
        }
        provisioner = {
          user = snowflake_service_user.provisioner.name
          secret_names = {
            account_identifier             = try(azurerm_key_vault_secret.snowflake_provisioner["snowflake-account-identifier"].name, null)
            account_identifier_privatelink = try(azurerm_key_vault_secret.snowflake_provisioner["snowflake-account-identifier-privatelink"].name, null)
            private_key                    = try(azurerm_key_vault_secret.snowflake_provisioner["snowflake-provisioner-private-key"].name, null)
            public_key                     = try(azurerm_key_vault_secret.snowflake_provisioner["snowflake-provisioner-public-key"].name, null)
          }
          secret_resource_ids = {
            account_identifier             = try(azurerm_key_vault_secret.snowflake_provisioner["snowflake-account-identifier"].resource_versionless_id, null)
            account_identifier_privatelink = try(azurerm_key_vault_secret.snowflake_provisioner["snowflake-account-identifier-privatelink"].resource_versionless_id, null)
          }
        }
      }
    })
  })
}
