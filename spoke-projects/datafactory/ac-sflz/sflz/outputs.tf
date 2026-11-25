output "landing_zone" {
  sensitive = true
  value = {
    name              = var.account.name
    identifier        = var.account.identifier
    cloud_platform    = var.account.cloud_platform
    organization_name = var.account.organization_name
    account_name      = var.account.account_name
    resource_names    = local.resource_names
    resource_ids      = one(module.azure[*].resource_ids)
    platform = {
      database   = snowflake_database.platform_db.name
      warehouse  = snowflake_warehouse.platform.name
      adf_role   = snowflake_account_role.platform_adf.name
      subnet_ids = var.account.cloud_platform == "azure" ? data.snowflake_system_get_snowflake_platform_info.platform_info.azure_vnet_subnet_ids : data.snowflake_system_get_snowflake_platform_info.platform_info.aws_vpc_ids
    }
    integrations = one(module.azure[*].integrations)
    sso = {
      saml_app_id        = azuread_application.snowflake_entraid_sso_app.client_id
      saml_app_name      = azuread_application.snowflake_entraid_sso_app.display_name
      saml_app_object_id = azuread_application.snowflake_entraid_sso_app.object_id
      saml_principal_id  = azuread_service_principal.snowflake_entraid_sso_principal.object_id
    }
    scim = {
      scim_integration_name       = snowflake_scim_integration.snowflake_entraid_scim.name
      scim_integration_properties = snowflake_scim_integration.snowflake_entraid_scim.describe_output
      scim_endpoint_id            = local.scim_endpoint_id
      scim_job_id                 = try(azuread_synchronization_job.snowflake_entraid_scim[0].id, null)
      service_user                = local.resource_names.snowflake.scim_service_user
      service_user_login_name     = local.resource_names.snowflake.scim_service_user
      provisioner_role            = local.resource_names.snowflake.scim_provisioner_role
    }
    containers = one(module.azure[*].containers)
  }
}
