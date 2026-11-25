# Keep the az1 landing zone addresses when the resources move under module.sflz_az1
moved {
  from = random_uuid.project_roles
  to   = module.sflz_az1.random_uuid.project_roles
}
moved {
  from = data.azuread_application_template.snowflake_entra_sso
  to   = module.sflz_az1.data.azuread_application_template.snowflake_entra_sso
}
moved {
  from = azuread_application.snowflake_entraid_sso_app
  to   = module.sflz_az1.azuread_application.snowflake_entraid_sso_app
}
moved {
  from = azuread_service_principal.snowflake_entraid_sso_principal
  to   = module.sflz_az1.azuread_service_principal.snowflake_entraid_sso_principal
}
moved {
  from = time_rotating.snowflake_entraid_sso_cert_rotation
  to   = module.sflz_az1.time_rotating.snowflake_entraid_sso_cert_rotation
}
moved {
  from = time_offset.snowflake_entraid_sso_cert_end
  to   = module.sflz_az1.time_offset.snowflake_entraid_sso_cert_end
}
moved {
  from = azuread_service_principal_token_signing_certificate.snowflake_entraid_sso_cert
  to   = module.sflz_az1.azuread_service_principal_token_signing_certificate.snowflake_entraid_sso_cert
}
moved {
  from = azuread_app_role_assignment.snowflake_entraid_sso_app_roles
  to   = module.sflz_az1.azuread_app_role_assignment.snowflake_entraid_sso_app_roles
}
moved {
  from = snowflake_grant_privileges_to_account_role.securityadmin_create_integration
  to   = module.sflz_az1.snowflake_grant_privileges_to_account_role.securityadmin_create_integration
}
moved {
  from = snowflake_saml2_integration.snowflake_entraid_sso_integration
  to   = module.sflz_az1.snowflake_saml2_integration.snowflake_entraid_sso_integration
}
moved {
  from = snowflake_scim_integration.snowflake_entraid_scim
  to   = module.sflz_az1.snowflake_scim_integration.snowflake_entraid_scim
}
moved {
  from = snowflake_grant_privileges_to_account_role.snowflake_entraid_scim_provisioner_integration_grant
  to   = module.sflz_az1.snowflake_grant_privileges_to_account_role.snowflake_entraid_scim_provisioner_integration_grant
}
moved {
  from = snowflake_execute.snowflake_entraid_scim_present
  to   = module.sflz_az1.snowflake_execute.snowflake_entraid_scim_present
}
moved {
  from = snowflake_execute.snowflake_entraid_scim_endpoint
  to   = module.sflz_az1.snowflake_execute.snowflake_entraid_scim_endpoint
}
moved {
  from = azuread_synchronization_secret.snowflake_entraid_scim
  to   = module.sflz_az1.azuread_synchronization_secret.snowflake_entraid_scim
}
moved {
  from = azuread_synchronization_job.snowflake_entraid_scim
  to   = module.sflz_az1.azuread_synchronization_job.snowflake_entraid_scim
}
moved {
  from = snowflake_account_role.project_roles
  to   = module.sflz_az1.snowflake_account_role.project_roles
}
moved {
  from = snowflake_grant_account_role.project_roles
  to   = module.sflz_az1.snowflake_grant_account_role.project_roles
}
moved {
  from = azurerm_role_assignment.dataset_roles_account_identifier
  to   = module.sflz_az1.azurerm_role_assignment.dataset_roles_account_identifier
}
moved {
  from = data.snowflake_system_get_snowflake_platform_info.platform_info
  to   = module.sflz_az1.data.snowflake_system_get_snowflake_platform_info.platform_info
}
moved {
  from = snowflake_warehouse.platform
  to   = module.sflz_az1.snowflake_warehouse.platform
}
moved {
  from = snowflake_database.platform_db
  to   = module.sflz_az1.snowflake_database.platform_db
}
moved {
  from = snowflake_schema.platform_schemas
  to   = module.sflz_az1.snowflake_schema.platform_schemas
}
moved {
  from = snowflake_account_role.platform_adf
  to   = module.sflz_az1.snowflake_account_role.platform_adf
}
moved {
  from = snowflake_grant_privileges_to_account_role.platform_adf_warehouse
  to   = module.sflz_az1.snowflake_grant_privileges_to_account_role.platform_adf_warehouse
}
moved {
  from = snowflake_grant_privileges_to_account_role.platform_adf_database
  to   = module.sflz_az1.snowflake_grant_privileges_to_account_role.platform_adf_database
}
moved {
  from = snowflake_grant_account_role.platform_adf_parent
  to   = module.sflz_az1.snowflake_grant_account_role.platform_adf_parent
}
moved {
  from = snowflake_grant_privileges_to_account_role.platform_admin_database
  to   = module.sflz_az1.snowflake_grant_privileges_to_account_role.platform_admin_database
}
moved {
  from = snowflake_grant_privileges_to_account_role.platform_admin_schemas
  to   = module.sflz_az1.snowflake_grant_privileges_to_account_role.platform_admin_schemas
}
moved {
  from = snowflake_resource_monitor.dataset_warehouse
  to   = module.sflz_az1.snowflake_resource_monitor.dataset_warehouse
}
moved {
  from = snowflake_warehouse.dataset_warehouse
  to   = module.sflz_az1.snowflake_warehouse.dataset_warehouse
}
moved {
  from = snowflake_account_role.dataset_warehouse_role
  to   = module.sflz_az1.snowflake_account_role.dataset_warehouse_role
}
moved {
  from = snowflake_grant_privileges_to_account_role.warehouse_usage
  to   = module.sflz_az1.snowflake_grant_privileges_to_account_role.warehouse_usage
}
moved {
  from = snowflake_grant_account_role.warehouse_role_parents
  to   = module.sflz_az1.snowflake_grant_account_role.warehouse_role_parents
}
moved {
  from = snowflake_database.dataset
  to   = module.sflz_az1.snowflake_database.dataset
}
moved {
  from = snowflake_grant_privileges_to_account_role.dataset_database_ingest_usage
  to   = module.sflz_az1.snowflake_grant_privileges_to_account_role.dataset_database_ingest_usage
}
moved {
  from = azurerm_storage_account.sflz_external_stage
  to   = module.sflz_az1.module.azure[0].azurerm_storage_account.sflz_external_stage
}
moved {
  from = azurerm_storage_management_policy.sflz_external_stage_retention
  to   = module.sflz_az1.module.azure[0].azurerm_storage_management_policy.sflz_external_stage_retention
}
moved {
  from = azurerm_storage_queue.sflz_notification_queue
  to   = module.sflz_az1.module.azure[0].azurerm_storage_queue.sflz_notification_queue
}
moved {
  from = snowflake_storage_integration_azure.sflz
  to   = module.sflz_az1.module.azure[0].snowflake_storage_integration_azure.sflz
}
moved {
  from = azuread_service_principal.sflz_storage_mta
  to   = module.sflz_az1.module.azure[0].azuread_service_principal.sflz_storage_mta
}
moved {
  from = snowflake_execute.external_stage_private_endpoint
  to   = module.sflz_az1.module.azure[0].snowflake_execute.external_stage_private_endpoint
}
moved {
  from = time_sleep.wait_for_ext_stage_blob_pe
  to   = module.sflz_az1.module.azure[0].time_sleep.wait_for_ext_stage_blob_pe
}
moved {
  from = data.azapi_resource_list.get_sf_end_ext_stage_blob
  to   = module.sflz_az1.module.azure[0].data.azapi_resource_list.get_sf_end_ext_stage_blob
}
moved {
  from = azapi_resource_action.approve_sf_end_ext_stage_blob
  to   = module.sflz_az1.module.azure[0].azapi_resource_action.approve_sf_end_ext_stage_blob
}
moved {
  from = snowflake_execute.external_stage_queue_private_endpoint
  to   = module.sflz_az1.module.azure[0].snowflake_execute.external_stage_queue_private_endpoint
}
moved {
  from = time_sleep.wait_for_ext_stage_queue_pe
  to   = module.sflz_az1.module.azure[0].time_sleep.wait_for_ext_stage_queue_pe
}
moved {
  from = data.azapi_resource_list.get_sf_end_ext_stage_queue
  to   = module.sflz_az1.module.azure[0].data.azapi_resource_list.get_sf_end_ext_stage_queue
}
moved {
  from = azapi_resource_action.approve_sf_end_ext_stage_queue
  to   = module.sflz_az1.module.azure[0].azapi_resource_action.approve_sf_end_ext_stage_queue
}
moved {
  from = azurerm_eventgrid_system_topic.sflz_external_stage_topic
  to   = module.sflz_az1.module.azure[0].azurerm_eventgrid_system_topic.sflz_external_stage_topic
}
moved {
  from = snowflake_execute.notification_integration_azure
  to   = module.sflz_az1.module.azure[0].snowflake_execute.notification_integration_azure
}
moved {
  from = azuread_service_principal.sflz_notification_mta
  to   = module.sflz_az1.module.azure[0].azuread_service_principal.sflz_notification_mta
}
moved {
  from = azurerm_role_assignment.sflz_storage_role_assignments
  to   = module.sflz_az1.module.azure[0].azurerm_role_assignment.sflz_storage_role_assignments
}
moved {
  from = azurerm_eventgrid_system_topic_event_subscription.sflz_external_stage_blob_events
  to   = module.sflz_az1.module.azure[0].azurerm_eventgrid_system_topic_event_subscription.sflz_external_stage_blob_events
}
moved {
  from = azuread_service_principal.sflz_workload_identity_mta
  to   = module.sflz_az1.module.azure[0].azuread_service_principal.sflz_workload_identity_mta
}
moved {
  from = data.snowflake_system_get_privatelink_config.snowflake_private_link
  to   = module.sflz_az1.module.azure[0].data.snowflake_system_get_privatelink_config.snowflake_private_link
}
moved {
  from = snowflake_execute.disable_internal_stage_public_access
  to   = module.sflz_az1.module.azure[0].snowflake_execute.disable_internal_stage_public_access
}
moved {
  from = module.pe_internal_stage_blob
  to   = module.sflz_az1.module.azure[0].module.pe_internal_stage_blob
}
moved {
  from = snowflake_execute.sflz_internal_stage_approve_private_link
  to   = module.sflz_az1.module.azure[0].snowflake_execute.sflz_internal_stage_approve_private_link
}
moved {
  from = azurerm_private_endpoint.pe_sflz_pvlinksvc
  to   = module.sflz_az1.module.azure[0].azurerm_private_endpoint.pe_sflz_pvlinksvc
}
moved {
  from = module.sflz_azure_access_token
  to   = module.sflz_az1.module.azure[0].module.sflz_azure_access_token
}
moved {
  from = snowflake_execute.pe_sflz_snowflake_service_approve_private_link
  to   = module.sflz_az1.module.azure[0].snowflake_execute.pe_sflz_snowflake_service_approve_private_link
}
moved {
  from = azurerm_private_dns_a_record.pe_sflz_snowflake_service_dns_a_record
  to   = module.sflz_az1.module.azure[0].azurerm_private_dns_a_record.pe_sflz_snowflake_service_dns_a_record
}
moved {
  from = azurerm_private_dns_cname_record.privatelink_snowflake_svc
  to   = module.sflz_az1.module.azure[0].azurerm_private_dns_cname_record.privatelink_snowflake_svc
}
moved {
  from = azurerm_private_dns_cname_record.privatelink_snowflake_app
  to   = module.sflz_az1.module.azure[0].azurerm_private_dns_cname_record.privatelink_snowflake_app
}
moved {
  from = azurerm_storage_container.layer
  to   = module.sflz_az1.module.azure[0].azurerm_storage_container.layer
}
moved {
  from = azurerm_role_assignment.layer_container_dataset_role
  to   = module.sflz_az1.module.azure[0].azurerm_role_assignment.layer_container_dataset_role
}
moved {
  from = snowflake_grant_privileges_to_account_role.sysadmin_storage_integration_usage
  to   = module.sflz_az1.module.azure[0].snowflake_grant_privileges_to_account_role.sysadmin_storage_integration_usage
}
moved {
  from = snowflake_grant_privileges_to_account_role.sysadmin_notification_integration_usage
  to   = module.sflz_az1.module.azure[0].snowflake_grant_privileges_to_account_role.sysadmin_notification_integration_usage
}
