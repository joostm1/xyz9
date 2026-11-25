# snowflake bootstrap: create the Terraform provisioner using the initial admin only
data "azurerm_key_vault_secret" "project_config" {
  name         = "${var.project_name}-config"
  key_vault_id = local.azhubs_vault_id
  provider     = azurerm.corp
}
data "azurerm_key_vault_secret" "client_p12" {
  name         = local.config.projects.azhubs.client.p12.name
  key_vault_id = local.config.projects.azhubs.vault.id
  provider     = azurerm.corp
}
# Read corp vault secret `snowflake-accounts` (xz9kviac)
data "azurerm_key_vault_secret" "snowflake_accounts" {
  name         = "snowflake-accounts"
  key_vault_id = var.corp_vault_id
  provider     = azurerm.corp
}
data "azurerm_key_vault_secret" "snowflake_admin_private_key" {
  for_each     = local.snowflake_accounts
  name         = each.value.private_key_secret_name
  key_vault_id = var.corp_vault_id
  provider     = azurerm.corp
}
resource "tls_private_key" "snowflake_provisioner" {
  for_each  = local.snowflake_accounts
  algorithm = "RSA"
  rsa_bits  = 2048
}
# Create the `kv-xyz9-datafactory` project vault and store the Snowflake provisioner's keys there
resource "azurerm_key_vault" "project" {
  name                          = "kv-${local.org.name}-${local.project.name}"
  location                      = local.config.projects.azhubs.spoke.rg.location
  resource_group_name           = local.config.projects.azhubs.spoke.rg.name
  tenant_id                     = var.tenant_id
  sku_name                      = "standard"
  rbac_authorization_enabled    = true
  public_network_access_enabled = true
  purge_protection_enabled      = false
  soft_delete_retention_days    = 7
}
resource "azurerm_role_assignment" "project_vault_owners" {
  for_each             = local.project_vault_owner_principals
  scope                = azurerm_key_vault.project.id
  role_definition_name = "Key Vault Administrator"
  principal_id         = each.value
}
resource "azurerm_role_assignment" "project_vault_secrets_user_runtime" {
  scope                = azurerm_key_vault.project.id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = local.config.projects.azhubs.client.service_principal.object_id
}
module "project_vault_rbac" {
  source               = "../../../catalog/terraform/modules/az/wait_for_rbac"
  for_each             = local.project_vault_owner_principals
  scope                = azurerm_key_vault.project.id
  role_definition_name = "Key Vault Administrator"
  object_id            = each.value
  assignment_id        = each.key
  depends_on           = [azurerm_role_assignment.project_vault_owners]
}
# Store each account's identifier and `TERRAFORM_PROVISIONER` key in `kv-xyz9-datafactory`
resource "azurerm_key_vault_secret" "snowflake_provisioner" {
  for_each = toset(flatten([
    for name, names in local.account_secret_names : values(names)
  ]))
  name         = each.value
  value        = local.snowflake_secret_values[each.value]
  key_vault_id = azurerm_key_vault.project.id
  depends_on   = [module.project_vault_rbac]
}
