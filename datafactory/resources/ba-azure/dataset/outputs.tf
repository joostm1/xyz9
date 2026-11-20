output "dataset" {
  value = {
    id             = module.adf.factory_id
    name           = module.adf.factory_name
    principal_id   = module.adf.principal_id
    resource_group = azurerm_resource_group.this.name
    vault_id       = azurerm_key_vault.this.id
    vault_name     = azurerm_key_vault.this.name
    adf_user       = snowflake_service_user.adf.name
    deploy         = module.adf.deploy
  }
}
