# snowflake bootstrap: create the Terraform provisioner using the initial admin only
data "azurerm_key_vault_secret" "project_config" {
  name         = "${var.project_name}-config"
  key_vault_id = var.corp_vault_id
  provider     = azurerm.corp
}
data "azurerm_key_vault_secret" "owner_p12" {
  name         = local.config.projects.projects.secret_names.secrets.owner_p12
  key_vault_id = var.corp_vault_id
  provider     = azurerm.corp
}
data "azurerm_key_vault_secret" "snowflake_account" {
  for_each = toset([
    "snowflake-account-identifier",
    "snowflake-account-username",
    "snowflake-account-private-key",
  ])
  name         = each.key
  key_vault_id = var.corp_vault_id
  provider     = azurerm.corp
}
resource "tls_private_key" "snowflake_provisioner" {
  algorithm = "RSA"
  rsa_bits  = 2048
}
# Create the `kv-xyz9-datafactory` project vault and store the Snowflake provisioner's keys there
resource "azurerm_key_vault" "project" {
  name                          = "kv-${local.org.name}-${local.project.name}"
  location                      = local.config.projects.datacenter.spoke.rg.location
  resource_group_name           = local.config.projects.datacenter.spoke.rg.name
  tenant_id                     = local.config.projects.projects.entra.tenant_id
  sku_name                      = "standard"
  rbac_authorization_enabled    = true
  public_network_access_enabled = true
  purge_protection_enabled      = false
  soft_delete_retention_days    = 7
}
resource "azurerm_role_assignment" "project_vault_owners" {
  for_each = {
    app   = local.config.projects.projects.identity.owner.app_object_id
    group = local.config.projects.projects.identity.owner.group_object_id
  }
  scope                = azurerm_key_vault.project.id
  role_definition_name = "Key Vault Administrator"
  principal_id         = each.value
}
module "project_vault_rbac" {
  source               = "../../org/terraform/modules/az/wait_for_rbac"
  for_each             = azurerm_role_assignment.project_vault_owners
  scope                = azurerm_key_vault.project.id
  role_definition_name = "Key Vault Administrator"
  object_id            = each.value.principal_id
  assignment_id        = each.value.id
}
resource "azurerm_key_vault_secret" "snowflake_provisioner" {
  for_each = {
    "snowflake-account-identifier"             = data.azurerm_key_vault_secret.snowflake_account["snowflake-account-identifier"].value
    "snowflake-account-identifier-privatelink" = "${lower(data.azurerm_key_vault_secret.snowflake_account["snowflake-account-identifier"].value)}.privatelink"
    "snowflake-provisioner-private-key"        = tls_private_key.snowflake_provisioner.private_key_pem
    "snowflake-provisioner-public-key"         = tls_private_key.snowflake_provisioner.public_key_pem
  }
  name         = each.key
  value        = each.value
  key_vault_id = azurerm_key_vault.project.id
  depends_on   = [module.project_vault_rbac]
}
resource "snowflake_service_user" "provisioner" {
  name                           = upper(local.config.snowflake.provisioner_username)
  login_name                     = lower(local.config.snowflake.provisioner_username)
  display_name                   = "Terraform Snowflake provisioner"
  comment                        = "Service user for Terraform-managed Snowflake landing zone resources."
  default_role                   = "ACCOUNTADMIN"
  default_secondary_roles_option = "NONE"
  default_warehouse              = "COMPUTE_WH"
  disabled                       = "false"
  rsa_public_key                 = tls_private_key.snowflake_provisioner.public_key_pem
  provider                       = snowflake.initial
}
resource "snowflake_grant_account_role" "provisioner_admin_roles" {
  for_each  = toset(["ACCOUNTADMIN", "SECURITYADMIN", "SYSADMIN", "USERADMIN"])
  role_name = each.value
  user_name = snowflake_service_user.provisioner.name
  provider  = snowflake.initial
}
resource "snowflake_grant_privileges_to_account_role" "admin_compute_warehouse_usage" {
  for_each          = toset(["ACCOUNTADMIN", "SECURITYADMIN", "SYSADMIN", "USERADMIN"])
  account_role_name = each.value
  privileges        = ["USAGE"]
  on_account_object {
    object_type = "WAREHOUSE"
    object_name = "COMPUTE_WH"
  }
  provider = snowflake.initial
}
# Set `ENABLE_INTERNAL_STAGES_PRIVATELINK` so as-sflz can read privatelink-internal-stage from SYSTEM$GET_PRIVATELINK_CONFIG
resource "snowflake_account_parameter" "enable_internal_stages_privatelink" {
  key      = "ENABLE_INTERNAL_STAGES_PRIVATELINK"
  value    = "true"
  provider = snowflake.initial
}
