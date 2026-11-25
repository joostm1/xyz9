output "resource_ids" {
  value = {
    ext_stage            = azurerm_storage_account.sflz_external_stage.id
    int_stage            = data.snowflake_system_get_privatelink_config.snowflake_private_link.internal_stage
    resource_group       = local.config.projects.azhubs.spoke.rg.id
    storage_queue        = azurerm_storage_queue.sflz_notification_queue.id
    storage_system_topic = azurerm_eventgrid_system_topic.sflz_external_stage_topic.id
  }
}
output "integrations" {
  value = {
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
}
output "containers" {
  value = {
    for dataset_key in keys(local.config.scopes.datasets) : dataset_key => {
      for key, row in module.dataset_x_layer_azure.by_key : row.container => {
        name = azurerm_storage_container.layer[key].name
        id   = azurerm_storage_container.layer[key].id
      } if row.dataset_key == dataset_key
    }
  }
}
