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
      saml_app_id                    = azuread_application.snowflake_entraid_sso_app.client_id
      saml_app_name                  = azuread_application.snowflake_entraid_sso_app.display_name
      saml_app_object_id             = azuread_application.snowflake_entraid_sso_app.object_id
      saml_principal_id              = azuread_service_principal.snowflake_entraid_sso_principal.object_id
      saml_privatelink_app_id        = azuread_application.snowflake_entraid_sso_app_privatelink.client_id
      saml_privatelink_app_name      = azuread_application.snowflake_entraid_sso_app_privatelink.display_name
      saml_privatelink_app_object_id = azuread_application.snowflake_entraid_sso_app_privatelink.object_id
      saml_privatelink_principal_id  = azuread_service_principal.snowflake_entraid_sso_principal_privatelink.object_id
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
    openflow = length(snowflake_openflow_runtime.sharepoint) == 0 ? null : {
      admin_role      = one(snowflake_account_role.openflow_admin[*].name)
      deployment      = one(snowflake_openflow_deployment_snowflake_managed.openflow[*].name)
      runtime         = one(snowflake_openflow_runtime.sharepoint[*].name)
      runtime_url     = try(one(snowflake_openflow_runtime.sharepoint[*].describe_output)[0].server_url, null)
      execute_as_role = one(snowflake_account_role.openflow_execute_as[*].name)
      connector = length(snowflake_openflow_connector.sharepoint) == 0 ? null : {
        name       = one(snowflake_openflow_connector.sharepoint[*].name)
        definition = try(one(snowflake_openflow_connector.sharepoint[*].show_output)[0].connector_definition, null)
        client_id  = one(azuread_application.openflow_sharepoint[*].client_id)
      }
    }
  }
}
