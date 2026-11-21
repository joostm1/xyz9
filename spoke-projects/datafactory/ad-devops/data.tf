# predecessor remote_state + corp secrets (p12); config lives in predecessor output
data "azurerm_key_vault_secret" "owner_p12" {
  name         = local.config.projects.projects.secret_names.secrets.owner_p12
  key_vault_id = var.corp_vault_id
  provider     = azurerm.corp
}
# our predecessor
data "terraform_remote_state" "as_sflz" {
  backend = "azurerm"
  config = {
    resource_group_name  = var.resource_group_name
    storage_account_name = var.storage_account_name
    container_name       = var.project_name
    key                  = "as-sflz.tfstate"
    use_azuread_auth     = true
    subscription_id      = split("/", var.corp_vault_id)[2]
    tenant_id            = var.tenant_id
  }
}
data "azurerm_key_vault_secret" "snowflake" {
  for_each     = toset(["snowflake-account-identifier", "snowflake-provisioner-private-key"])
  name         = each.value
  key_vault_id = local.config.roots["am-sfbootstrap"].project_vault_id
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
