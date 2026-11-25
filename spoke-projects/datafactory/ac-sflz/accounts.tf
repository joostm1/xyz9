# Provider aliases cannot be for_each'd. `az1` keeps accountadmin/securityadmin/sysadmin; `aw1` uses the aw1_ aliases.
module "sflz_az1" {
  source            = "./sflz"
  account           = local.snowflake_accounts["az1"]
  config            = local.config
  project           = local.project
  tenant_id         = var.tenant_id
  private_dns_rg_id = local.private_dns_rg_id
  entra_groups      = local.entra_groups
  client_p12        = data.azurerm_key_vault_secret.owner_p12.value
  scim_pat          = data.azurerm_key_vault_secret.snowflake[local.snowflake_accounts["az1"].scim.pat_secret_name].value
  providers = {
    snowflake.accountadmin  = snowflake.accountadmin
    snowflake.securityadmin = snowflake.securityadmin
    snowflake.sysadmin      = snowflake.sysadmin
  }
}
module "sflz_aw1" {
  source            = "./sflz"
  account           = local.snowflake_accounts["aw1"]
  config            = local.config
  project           = local.project
  tenant_id         = var.tenant_id
  private_dns_rg_id = local.private_dns_rg_id
  entra_groups      = local.entra_groups
  client_p12        = data.azurerm_key_vault_secret.owner_p12.value
  scim_pat          = data.azurerm_key_vault_secret.snowflake[local.snowflake_accounts["aw1"].scim.pat_secret_name].value
  providers = {
    snowflake.accountadmin  = snowflake.aw1_accountadmin
    snowflake.securityadmin = snowflake.aw1_securityadmin
    snowflake.sysadmin      = snowflake.aw1_sysadmin
  }
}
locals {
  sflz_landing_zones = {
    az1 = module.sflz_az1.landing_zone
    aw1 = module.sflz_aw1.landing_zone
  }
}
