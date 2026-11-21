# same-project handoff: full living object with this root under roots[state_key]
output "config" {
  value = merge(local.config, {
    roots = merge(try(local.config.roots, {}), {
      (var.state_key) = {
        resource_names = local.resource_names
        resource_ids = {
          ext_stage            = azurerm_storage_account.sflz_external_stage.id
          int_stage            = data.snowflake_system_get_privatelink_config.snowflake_private_link.internal_stage
          resource_group       = local.config.projects.datacenter.spoke.rg.id
          storage_queue        = azurerm_storage_queue.sflz_notification_queue.id
          storage_system_topic = azurerm_eventgrid_system_topic.sflz_external_stage_topic.id
        }
        platform = {
          database   = snowflake_database.platform_db.name
          warehouse  = snowflake_warehouse.platform.name
          adf_role   = snowflake_account_role.platform_adf.name
          subnet_ids = data.snowflake_system_get_snowflake_platform_info.platform_info.azure_vnet_subnet_ids
        }
        integrations = {
          storage_name      = local.resource_names.snowflake.storage_integration
          notification_name = local.resource_names.snowflake.notification_integration
          storage = {
            client_id = azuread_service_principal.sflz_storage_mta.client_id
            object_id = azuread_service_principal.sflz_storage_mta.object_id
            name      = azuread_service_principal.sflz_storage_mta.display_name
          }
          notification = try({
            client_id = azuread_service_principal.sflz_notification_mta[0].client_id
            object_id = azuread_service_principal.sflz_notification_mta[0].object_id
            name      = azuread_service_principal.sflz_notification_mta[0].display_name
          }, null)
          workload_identity = {
            client_id = azuread_service_principal.sflz_workload_identity_mta.client_id
            object_id = azuread_service_principal.sflz_workload_identity_mta.object_id
            name      = azuread_service_principal.sflz_workload_identity_mta.display_name
          }
        }
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
        roles = {
          platform = {
            for role in local.config.scopes.platform.roles : "platform-${role}" => {
              object_id    = azuread_group.project_roles["platform-${role}"].object_id
              display_name = azuread_group.project_roles["platform-${role}"].display_name
            }
          }
          datasets = merge([
            for dataset_key, dataset in local.config.scopes.datasets : {
              for role in dataset.roles : "${dataset_key}-${role}" => {
                dataset_key  = dataset_key
                role         = role
                object_id    = azuread_group.project_roles["dataset-${dataset_key}-${role}"].object_id
                display_name = azuread_group.project_roles["dataset-${dataset_key}-${role}"].display_name
              }
            }
          ]...)
        }
        containers = {
          for dataset_key in keys(local.config.scopes.datasets) : dataset_key => {
            for key, row in module.dataset_x_layer_azure.by_key : row.container => {
              name = azurerm_storage_container.layer[key].name
              id   = azurerm_storage_container.layer[key].id
            } if row.dataset_key == dataset_key
          }
        }
      }
    })
  })
  sensitive = true
}
