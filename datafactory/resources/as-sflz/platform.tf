# account platform objects: PLATFORM warehouse, PLATFORM database/schemas, PLATFORM_ADF role
# network policies (`ALLOW_ALL`, `DBT_CLOUD`) are created in am-sfbootstrap
data "snowflake_system_get_snowflake_platform_info" "platform_info" {
  provider = snowflake.accountadmin
}
# platform warehouse for PLATFORM_ADF (no resource monitor; SYSADMIN owns it)
resource "snowflake_warehouse" "platform" {
  name           = local.config.snowflake.platform.warehouse.name
  warehouse_size = local.config.snowflake.platform.warehouse.size
  auto_suspend   = local.config.snowflake.platform.warehouse.auto_suspend
  auto_resume    = tostring(local.config.snowflake.platform.warehouse.auto_resume)
  comment        = "Control-plane warehouse for the platform ADF service user."
  provider       = snowflake.sysadmin
}
# platform database + schemas
resource "snowflake_database" "platform_db" {
  name     = local.config.snowflake.platform.database.name
  comment  = local.config.snowflake.platform.database.comment
  provider = snowflake.sysadmin
}
resource "snowflake_schema" "platform_schemas" {
  for_each = local.config.snowflake.platform.database.schemas
  name     = each.value.name
  database = snowflake_database.platform_db.name
  comment  = each.value.comment
  provider = snowflake.sysadmin
}
resource "snowflake_account_role" "platform_adf" {
  name     = "PLATFORM_ADF"
  comment  = "Runtime role for the platform ADF service user."
  provider = snowflake.securityadmin
}
resource "snowflake_grant_privileges_to_account_role" "platform_adf_warehouse" {
  account_role_name = snowflake_account_role.platform_adf.name
  privileges        = ["USAGE"]
  on_account_object {
    object_type = "WAREHOUSE"
    object_name = snowflake_warehouse.platform.name
  }
  provider = snowflake.securityadmin
}
resource "snowflake_grant_privileges_to_account_role" "platform_adf_database" {
  account_role_name = snowflake_account_role.platform_adf.name
  privileges        = ["USAGE"]
  on_account_object {
    object_type = "DATABASE"
    object_name = snowflake_database.platform_db.name
  }
  provider = snowflake.sysadmin
}
resource "snowflake_grant_account_role" "platform_adf_parent" {
  role_name        = snowflake_account_role.platform_adf.name
  parent_role_name = snowflake_account_role.project_roles[local.config.snowflake.platform.database.parent_role_key].name
  provider         = snowflake.securityadmin
}
resource "snowflake_grant_privileges_to_account_role" "platform_admin_database" {
  account_role_name = snowflake_account_role.project_roles[local.config.snowflake.platform.database.parent_role_key].name
  all_privileges    = true
  with_grant_option = true
  on_account_object {
    object_type = "DATABASE"
    object_name = snowflake_database.platform_db.name
  }
  provider = snowflake.sysadmin
}
resource "snowflake_grant_privileges_to_account_role" "platform_admin_schemas" {
  for_each          = snowflake_schema.platform_schemas
  account_role_name = snowflake_account_role.project_roles[local.config.snowflake.platform.database.parent_role_key].name
  all_privileges    = true
  with_grant_option = true
  on_schema {
    schema_name = each.value.fully_qualified_name
  }
  provider = snowflake.sysadmin
}
