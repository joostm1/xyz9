# Snowflake service user for the platform ADF; USERADMIN creates the user, SECURITYADMIN grants PLATFORM_ADF
resource "tls_private_key" "platform_adf" {
  algorithm = "RSA"
  rsa_bits  = 2048
}
resource "snowflake_service_user" "platform_adf" {
  name                           = "PLATFORM_ADF"
  login_name                     = "platform_adf"
  display_name                   = "ADF service user for platform"
  comment                        = "Key-pair user for the platform data factory linked service."
  default_role                   = local.config.roots["ac-sflz"].platform.adf_role
  default_warehouse              = local.config.roots["ac-sflz"].platform.warehouse
  default_secondary_roles_option = "NONE"
  disabled                       = "false"
  rsa_public_key                 = tls_private_key.platform_adf.public_key_pem
  provider                       = snowflake.useradmin
}
resource "snowflake_grant_account_role" "platform_adf" {
  role_name = local.config.roots["ac-sflz"].platform.adf_role
  user_name = snowflake_service_user.platform_adf.name
  provider  = snowflake.securityadmin
}
resource "azurerm_key_vault_secret" "platform_adf_key" {
  name         = "snowflake-adf-key"
  value        = tls_private_key.platform_adf.private_key_pem_pkcs8
  key_vault_id = local.config.roots["am-sfbootstrap"].project_vault_id
}
