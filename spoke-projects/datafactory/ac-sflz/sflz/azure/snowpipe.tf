# grant SYSADMIN usage on integrations so successor root modules can create stages/pipes
resource "snowflake_grant_privileges_to_account_role" "sysadmin_storage_integration_usage" {
  account_role_name = "SYSADMIN"
  privileges        = ["USAGE"]
  on_account_object {
    object_type = "INTEGRATION"
    object_name = local.resource_names.snowflake.storage_integration
  }
  depends_on = [snowflake_storage_integration_azure.sflz]
  lifecycle {
    replace_triggered_by = [snowflake_storage_integration_azure.sflz]
  }
  provider = snowflake.accountadmin
}
resource "snowflake_grant_privileges_to_account_role" "sysadmin_notification_integration_usage" {
  count             = 1
  account_role_name = "SYSADMIN"
  privileges        = ["USAGE"]
  on_account_object {
    object_type = "INTEGRATION"
    object_name = local.resource_names.snowflake.notification_integration
  }
  depends_on = [snowflake_execute.notification_integration_azure]
  lifecycle {
    replace_triggered_by = [snowflake_execute.notification_integration_azure]
  }
  provider = snowflake.accountadmin
}
