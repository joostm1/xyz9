# predecessor remote state; `datafactory-owner-p12` lives in `kv-xyz9-azhubs`
data "azurerm_key_vault_secret" "owner_p12" {
  name         = local.config.projects.azhubs.client.p12.name
  key_vault_id = local.config.projects.azhubs.vault.id
  provider     = azurerm.corp
}
data "terraform_remote_state" "am_sfbootstrap" {
  backend = "azurerm"
  config = {
    resource_group_name  = var.resource_group_name
    storage_account_name = var.storage_account_name
    container_name       = var.project_name
    key                  = "ab-sfbootstrap.tfstate"
    use_azuread_auth     = true
    subscription_id      = split("/", var.corp_vault_id)[2]
    tenant_id            = var.tenant_id
  }
}
data "azurerm_key_vault_secret" "snowflake" {
  for_each = toset(flatten([
    for account in local.snowflake_accounts : [
      account.provisioner.secret_names.private_key,
      account.scim.pat_secret_name,
    ]
  ]))
  name         = each.value
  key_vault_id = local.config.roots["ab-sfbootstrap"].project_vault_id
}
module "project_roles" {
  source          = "../../../catalog/terraform/modules/scope_enumerator"
  tree            = try(local.project.scopes, {})
  enum_key        = "roles"
  enum_value_name = "role"
  segment_translations = {
    datasets = "dataset"
  }
}
