# Create `AAD_PROVISIONER` and `SCIM_PROVISIONER` so as-sflz can plan the SCIM PAT
resource "snowflake_account_role" "scim_provisioner" {
  name     = "AAD_PROVISIONER"
  comment  = "Role used by Entra SCIM provisioning."
  provider = snowflake.initial
}
resource "snowflake_grant_privileges_to_account_role" "scim_provisioner_account_grants" {
  account_role_name = snowflake_account_role.scim_provisioner.name
  privileges        = ["CREATE USER", "CREATE ROLE"]
  on_account        = true
  provider          = snowflake.initial
}
resource "snowflake_grant_account_role" "scim_provisioner_accountadmin_grant" {
  role_name        = snowflake_account_role.scim_provisioner.name
  parent_role_name = "ACCOUNTADMIN"
  provider         = snowflake.initial
}
resource "snowflake_service_user" "scim" {
  name                           = "SCIM_PROVISIONER"
  login_name                     = "SCIM_PROVISIONER"
  display_name                   = "Microsoft Entra SCIM provisioning"
  comment                        = "Service user for Microsoft Entra SCIM provisioning managed by Terraform."
  default_role                   = snowflake_account_role.scim_provisioner.name
  default_secondary_roles_option = "NONE"
  disabled                       = "false"
  network_policy                 = snowflake_network_policy.platform["allow-all"].name
  provider                       = snowflake.initial
}
resource "snowflake_grant_account_role" "scim_service_user_role_grant" {
  role_name = snowflake_account_role.scim_provisioner.name
  user_name = snowflake_service_user.scim.name
  provider  = snowflake.initial
}
# SECURITYADMIN owns `SCIM_PROVISIONER` so as-sflz can DESCRIBE the user
resource "snowflake_grant_ownership" "scim_user_securityadmin" {
  account_role_name   = "SECURITYADMIN"
  outbound_privileges = "COPY"
  on {
    object_type = "USER"
    object_name = snowflake_service_user.scim.name
  }
  provider = snowflake.initial
}
resource "time_rotating" "scim_pat" {
  rotation_days = 330
}
# Create PAT `ENTRA_SCIM` on `SCIM_PROVISIONER` and store it in `kv-xyz9-datafactory` as `snowflake-scim-pat`
resource "snowflake_user_programmatic_access_token" "scim" {
  name                             = "ENTRA_SCIM"
  user                             = snowflake_service_user.scim.name
  role_restriction                 = snowflake_account_role.scim_provisioner.name
  days_to_expiry                   = 365
  expire_rotated_token_after_hours = 24
  keeper                           = time_rotating.scim_pat.id
  comment                          = "Programmatic access token for Microsoft Entra SCIM provisioning."
  depends_on = [
    snowflake_grant_account_role.scim_service_user_role_grant,
    snowflake_service_user.scim,
  ]
  provider = snowflake.initial
}
resource "azurerm_key_vault_secret" "scim_pat" {
  name         = "snowflake-scim-pat"
  value        = snowflake_user_programmatic_access_token.scim.token
  key_vault_id = azurerm_key_vault.project.id
  depends_on   = [module.project_vault_rbac]
}
