# Catalog definitions for the SharePoint simple-ingest connector; `min_runtime_node_type` sizes runtime `SHAREPOINT` before it is created
data "snowflake_openflow_connector_definitions" "sharepoint" {
  count    = local.openflow_enabled ? 1 : 0
  provider = snowflake.accountadmin
}
# Create `OPENFLOW_ADMIN` so a platform admin can open the Openflow UI without using `ACCOUNTADMIN`
resource "snowflake_account_role" "openflow_admin" {
  count    = local.openflow_enabled ? 1 : 0
  name     = local.resource_names.snowflake.openflow.admin_role
  comment  = "Openflow administration for account ${var.account.name}."
  provider = snowflake.securityadmin
}
resource "snowflake_grant_privileges_to_account_role" "openflow_admin_account" {
  count             = local.openflow_enabled ? 1 : 0
  account_role_name = snowflake_account_role.openflow_admin[0].name
  privileges        = ["CREATE OPENFLOW DEPLOYMENT", "CREATE DATABASE", "CREATE INTEGRATION", "CREATE COMPUTE POOL", "CREATE WAREHOUSE"]
  on_account        = true
  provider          = snowflake.accountadmin
}
# Grant `OPENFLOW_ADMIN` to `sg-datafactory-platform-admin` so that Entra role can open the deployment
resource "snowflake_grant_account_role" "openflow_admin_platform_admin" {
  count            = local.openflow_enabled ? 1 : 0
  role_name        = snowflake_account_role.openflow_admin[0].name
  parent_role_name = upper(var.entra_groups["platform-admin"].display_name)
  provider         = snowflake.securityadmin
}
# Create `OPENFLOW_SHAREPOINT_EXECUTE_AS_RL` before runtime `SHAREPOINT`; the runtime does not create this role
resource "snowflake_account_role" "openflow_execute_as" {
  count    = local.openflow_enabled ? 1 : 0
  name     = local.resource_names.snowflake.openflow.execute_as_role
  comment  = "Execute-as role for Openflow runtime SHAREPOINT."
  provider = snowflake.securityadmin
}
# Grant `OPENFLOW_SHAREPOINT_EXECUTE_AS_RL` to `ACCOUNTADMIN` so the provisioner can create runtime `SHAREPOINT`
resource "snowflake_grant_account_role" "openflow_execute_as_accountadmin" {
  count            = local.openflow_enabled ? 1 : 0
  role_name        = snowflake_account_role.openflow_execute_as[0].name
  parent_role_name = "ACCOUNTADMIN"
  provider         = snowflake.securityadmin
}
# Create control database `OPENFLOW` for the runtime, network rule, secret, and connector
resource "snowflake_database" "openflow" {
  count    = local.openflow_enabled ? 1 : 0
  name     = local.resource_names.snowflake.openflow.database
  comment  = "Openflow control-plane objects. Connector data lands in SHAREPOINT."
  provider = snowflake.sysadmin
}
resource "snowflake_schema" "openflow_control" {
  count    = local.openflow_enabled ? 1 : 0
  name     = local.resource_names.snowflake.openflow.schema
  database = snowflake_database.openflow[0].name
  comment  = "Openflow runtime, network rule, secret, and connector."
  provider = snowflake.sysadmin
}
resource "snowflake_grant_privileges_to_account_role" "openflow_admin_database" {
  count             = local.openflow_enabled ? 1 : 0
  account_role_name = snowflake_account_role.openflow_admin[0].name
  privileges        = ["USAGE"]
  on_account_object {
    object_type = "DATABASE"
    object_name = snowflake_database.openflow[0].name
  }
  provider = snowflake.sysadmin
}
resource "snowflake_grant_privileges_to_account_role" "openflow_admin_schema" {
  count             = local.openflow_enabled ? 1 : 0
  account_role_name = snowflake_account_role.openflow_admin[0].name
  privileges        = ["USAGE"]
  on_schema {
    schema_name = snowflake_schema.openflow_control[0].fully_qualified_name
  }
  provider = snowflake.sysadmin
}
# Create Snowflake-managed deployment `OPENFLOW` on account `az1`
resource "snowflake_openflow_deployment_snowflake_managed" "openflow" {
  count            = local.openflow_enabled ? 1 : 0
  name             = local.resource_names.snowflake.openflow.deployment
  comment          = "Snowflake-managed Openflow deployment for account ${var.account.name}."
  use_private_link = "true"
  provider         = snowflake.accountadmin
  timeouts {
    create = "60m"
    update = "60m"
    delete = "60m"
  }
}
resource "snowflake_grant_privileges_to_account_role" "openflow_admin_deployment" {
  count             = local.openflow_enabled ? 1 : 0
  account_role_name = snowflake_account_role.openflow_admin[0].name
  privileges        = ["USAGE"]
  on_account_object {
    object_type = "OPENFLOW DEPLOYMENT"
    object_name = snowflake_openflow_deployment_snowflake_managed.openflow[0].name
  }
  provider = snowflake.accountadmin
}
# Create runtime `SHAREPOINT` in `OPENFLOW.CONTROL`; node size follows the SharePoint connector minimum
resource "snowflake_openflow_runtime" "sharepoint" {
  count                        = local.openflow_enabled ? 1 : 0
  database                     = snowflake_database.openflow[0].name
  schema                       = snowflake_schema.openflow_control[0].name
  name                         = local.resource_names.snowflake.openflow.runtime
  deployment                   = snowflake_openflow_deployment_snowflake_managed.openflow[0].name
  node_type                    = local.openflow_node_type
  min_nodes                    = 1
  max_nodes                    = 1
  execute_as_role              = snowflake_account_role.openflow_execute_as[0].name
  external_access_integrations = length(snowflake_external_access_integration.sharepoint) == 0 ? null : toset(snowflake_external_access_integration.sharepoint[*].name)
  comment                      = "Openflow runtime for the SharePoint simple-ingest connector."
  provider                     = snowflake.accountadmin
  depends_on                   = [snowflake_grant_account_role.openflow_execute_as_accountadmin]
  timeouts {
    create = "60m"
    update = "60m"
    delete = "60m"
  }
}
