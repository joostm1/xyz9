# Entra SCIM provisioning into Snowflake (`AAD_PROVISIONER` / `SCIM_PROVISIONER` come from am-sfbootstrap)
resource "snowflake_scim_integration" "snowflake_entraid_scim" {
  name           = local.resource_names.snowflake.scim_integration
  enabled        = true
  scim_client    = "AZURE"
  run_as_role    = upper(local.resource_names.snowflake.scim_provisioner_role)
  network_policy = local.config.snowflake.platform.network_policies["allow-all"].name
  comment        = "SCIM integration for Entra provisioning."
  provider       = snowflake.accountadmin
}
resource "snowflake_grant_privileges_to_account_role" "snowflake_entraid_scim_provisioner_integration_grant" {
  account_role_name = local.resource_names.snowflake.scim_provisioner_role
  privileges        = ["USAGE"]
  on_account_object {
    object_type = "INTEGRATION"
    object_name = snowflake_scim_integration.snowflake_entraid_scim.name
  }
  provider = snowflake.securityadmin
}
resource "snowflake_execute" "snowflake_entraid_scim_present" {
  execute  = "SELECT 1"
  revert   = "SELECT 1"
  query    = <<-EOT
    SHOW SECURITY INTEGRATIONS LIKE '${local.resource_names.snowflake.scim_integration}'
    ->> SELECT "name" AS "name" FROM $1
  EOT
  provider = snowflake.accountadmin
}
resource "snowflake_execute" "snowflake_entraid_scim_endpoint" {
  count    = local.scim_integration_present ? 1 : 0
  execute  = "SELECT 1"
  revert   = "SELECT 1"
  query    = <<-EOT
    DESCRIBE SECURITY INTEGRATION ${local.resource_names.snowflake.scim_integration}
    ->> SELECT "property_value" AS "scim_endpoint_id"
    FROM $1
    WHERE "property" = 'SCIM_ENDPOINT_ID'
  EOT
  provider = snowflake.accountadmin
}
resource "azuread_synchronization_secret" "snowflake_entraid_scim" {
  count                = local.scim_integration_present ? 1 : 0
  service_principal_id = "/servicePrincipals/${azuread_service_principal.snowflake_entraid_sso_principal.object_id}"
  credential {
    key   = "BaseAddress"
    value = "https://${lower(data.azurerm_key_vault_secret.snowflake["snowflake-account-identifier"].value)}.${local.resource_names.snowflake.service_urls.svc}/scim/v2/${local.scim_endpoint_id}/"
  }
  credential {
    key   = "SecretToken"
    value = data.azurerm_key_vault_secret.snowflake["snowflake-scim-pat"].value
  }
}
# sync now button
resource "azuread_synchronization_job" "snowflake_entraid_scim" {
  count                = local.scim_integration_present ? 1 : 0
  service_principal_id = "/servicePrincipals/${azuread_service_principal.snowflake_entraid_sso_principal.object_id}"
  template_id          = "snowFlake"
  enabled              = true
  depends_on = [
    azuread_synchronization_secret.snowflake_entraid_scim,
    snowflake_account_role.project_roles,
  ]
}
