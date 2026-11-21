# Snowflake service user for ADF KeyPair auth; USERADMIN creates the user, SECURITYADMIN grants the ingest role
resource "tls_private_key" "adf" {
  algorithm = "RSA"
  rsa_bits  = 2048
}
resource "snowflake_service_user" "adf" {
  name                           = upper("${var.dataset_key}_adf")
  login_name                     = lower("${var.dataset_key}_adf")
  display_name                   = "ADF service user for dataset ${var.dataset_key}"
  comment                        = "Key-pair user for the ${var.dataset_key} data factory linked service."
  default_role                   = upper("${var.dataset_key}_ingest")
  default_warehouse              = upper("${var.dataset_key}_ingest")
  default_secondary_roles_option = "NONE"
  disabled                       = "false"
  rsa_public_key                 = tls_private_key.adf.public_key_pem
  provider                       = snowflake.useradmin
}
resource "snowflake_grant_account_role" "adf_ingest" {
  role_name = upper("${var.dataset_key}_ingest")
  user_name = snowflake_service_user.adf.name
  provider  = snowflake.securityadmin
}
resource "azurerm_key_vault_secret" "adf_key" {
  name         = "snowflake-adf-key"
  value        = tls_private_key.adf.private_key_pem_pkcs8
  key_vault_id = azurerm_key_vault.this.id
  depends_on   = [azurerm_role_assignment.owner_app]
}
