# Terraform-owned Snowflake roles linked under Entra/SCIM-provisioned parent role names
# entra's scim client provisiones roles like 'sg-datafactory-platform-admin', i.e., the display name of the ad group connected to the app role
# this was ugly at first sight and a good idea later on; a clear demarcation between scim and terraform as provisioner
resource "snowflake_account_role" "project_roles" {
  for_each = module.project_roles.by_key
  name     = upper(replace(each.key, "-", "_"))
  comment  = "Project role for ${each.key}"
  provider = snowflake.securityadmin
}
# role connection/demarcation point; GRANT ROLE <child> TO ROLE <parent>
resource "snowflake_grant_account_role" "project_roles" {
  for_each         = module.project_roles.by_key
  parent_role_name = upper(azuread_group.project_roles[each.key].display_name)
  role_name        = snowflake_account_role.project_roles[each.key].name
  provider         = snowflake.securityadmin
}
# dataset data roles may read the shared Snowflake account identifier _secret_
resource "azurerm_role_assignment" "dataset_roles_account_identifier" {
  for_each = {
    for key, group in azuread_group.project_roles : key => group
    if startswith(key, "dataset-")
  }
  scope                = local.config.roots["ab-sfbootstrap"].provisioner.secret_resource_ids.account_identifier
  role_definition_name = "Key Vault Secrets User"
  principal_id         = each.value.object_id
  principal_type       = "Group"
}
