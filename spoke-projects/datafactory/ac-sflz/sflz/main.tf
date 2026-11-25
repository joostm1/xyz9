module "project_roles" {
  source          = "../../../../catalog/terraform/modules/scope_enumerator"
  tree            = try(local.project.scopes, {})
  enum_key        = "roles"
  enum_value_name = "role"
  segment_translations = {
    datasets = "dataset"
  }
}
# Azure private link, storage, and Snowpipe exist only for cloud_platform azure
module "azure" {
  count             = var.account.cloud_platform == "azure" ? 1 : 0
  source            = "./azure"
  account           = var.account
  config            = var.config
  project           = var.project
  tenant_id         = var.tenant_id
  private_dns_rg_id = var.private_dns_rg_id
  entra_groups      = var.entra_groups
  client_p12        = var.client_p12
  resource_names    = local.resource_names
  providers = {
    snowflake.accountadmin = snowflake.accountadmin
  }
}
