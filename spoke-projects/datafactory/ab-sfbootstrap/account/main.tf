# Create account network policies (`ALLOW_ALL`, `DBT_CLOUD`) before the SCIM PAT
resource "snowflake_network_policy" "platform" {
  for_each        = var.network_policies
  name            = each.value.name
  allowed_ip_list = each.value.allowed_ip_list
  comment         = each.value.comment
}
# SECURITYADMIN owns the policies so ac-sflz can DESCRIBE `ALLOW_ALL` on the SCIM integration
resource "snowflake_grant_ownership" "platform_network_policy_securityadmin" {
  for_each            = var.network_policies
  account_role_name   = "SECURITYADMIN"
  outbound_privileges = "COPY"
  on {
    object_type = "NETWORK POLICY"
    object_name = snowflake_network_policy.platform[each.key].name
  }
}
resource "snowflake_service_user" "provisioner" {
  name                           = upper(var.provisioner_username)
  login_name                     = lower(var.provisioner_username)
  display_name                   = "Terraform Snowflake provisioner"
  comment                        = "Service user for Terraform-managed Snowflake landing zone resources."
  default_role                   = "ACCOUNTADMIN"
  default_secondary_roles_option = "NONE"
  default_warehouse              = "COMPUTE_WH"
  disabled                       = "false"
  rsa_public_key                 = var.provisioner_public_key
}
resource "snowflake_grant_account_role" "provisioner_admin_roles" {
  for_each  = toset(["ACCOUNTADMIN", "SECURITYADMIN", "SYSADMIN", "USERADMIN"])
  role_name = each.value
  user_name = snowflake_service_user.provisioner.name
}
resource "snowflake_grant_privileges_to_account_role" "admin_compute_warehouse_usage" {
  for_each          = toset(["ACCOUNTADMIN", "SECURITYADMIN", "SYSADMIN", "USERADMIN"])
  account_role_name = each.value
  privileges        = ["USAGE"]
  on_account_object {
    object_type = "WAREHOUSE"
    object_name = "COMPUTE_WH"
  }
}
# Enable `ENABLE_INTERNAL_STAGES_PRIVATELINK` on Azure accounts so ac-sflz can read SYSTEM$GET_PRIVATELINK_CONFIG
resource "snowflake_account_parameter" "enable_internal_stages_privatelink" {
  count = var.account.cloud_platform == "azure" ? 1 : 0
  key   = "ENABLE_INTERNAL_STAGES_PRIVATELINK"
  value = "true"
}
# Create `AAD_PROVISIONER` and `SCIM_PROVISIONER` so ac-sflz can plan the SCIM PAT
resource "snowflake_account_role" "scim_provisioner" {
  name    = "AAD_PROVISIONER"
  comment = "Role used by Entra SCIM provisioning."
}
resource "snowflake_grant_privileges_to_account_role" "scim_provisioner_account_grants" {
  account_role_name = snowflake_account_role.scim_provisioner.name
  privileges        = ["CREATE USER", "CREATE ROLE"]
  on_account        = true
}
resource "snowflake_grant_account_role" "scim_provisioner_accountadmin_grant" {
  role_name        = snowflake_account_role.scim_provisioner.name
  parent_role_name = "ACCOUNTADMIN"
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
}
resource "snowflake_grant_account_role" "scim_service_user_role_grant" {
  role_name = snowflake_account_role.scim_provisioner.name
  user_name = snowflake_service_user.scim.name
}
# SECURITYADMIN owns `SCIM_PROVISIONER` so ac-sflz can DESCRIBE the user
resource "snowflake_grant_ownership" "scim_user_securityadmin" {
  account_role_name   = "SECURITYADMIN"
  outbound_privileges = "COPY"
  on {
    object_type = "USER"
    object_name = snowflake_service_user.scim.name
  }
}
resource "time_rotating" "scim_pat" {
  rotation_days = 330
}
# Create PAT `ENTRA_SCIM` on `SCIM_PROVISIONER`; the root stores it in `kv-xyz9-datafactory`
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
}
