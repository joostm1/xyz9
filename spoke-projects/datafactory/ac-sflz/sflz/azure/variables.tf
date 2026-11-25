variable "account" {
  type = any
}
variable "config" {
  type = any
}
variable "project" {
  type = any
}
variable "tenant_id" {
  type = string
}
variable "private_dns_rg_id" {
  type = string
}
variable "entra_groups" {
  type = any
}
variable "client_p12" {
  type      = string
  sensitive = true
}
variable "resource_names" {
  type = any
}
locals {
  config            = var.config
  project           = var.project
  resource_names    = var.resource_names
  private_dns_rg_id = var.private_dns_rg_id
  ext_stage_blob_pe_connection = length(snowflake_execute.external_stage_private_endpoint.query_results) == 0 ? null : one([
    for c in try(data.azapi_resource_list.get_sf_end_ext_stage_blob.output.connections, []) : c.name
    if lower(try(c.private_endpoint_id, "")) == lower(snowflake_execute.external_stage_private_endpoint.query_results[0].snowflake_resource_id)
  ])
  ext_stage_queue_pe_connection = length(snowflake_execute.external_stage_queue_private_endpoint.query_results) == 0 ? null : one([
    for c in try(data.azapi_resource_list.get_sf_end_ext_stage_queue.output.connections, []) : c.name
    if lower(try(c.private_endpoint_id, "")) == lower(snowflake_execute.external_stage_queue_private_endpoint.query_results[0].snowflake_resource_id)
  ])
  storage_integration_client_id      = try(regex("client_id=([^&]+)", snowflake_storage_integration_azure.sflz.describe_output[0].consent_url)[0], null)
  notification_integration_client_id = try(snowflake_execute.notification_integration_azure[0].query_results[0].client_id, null)
  sflz_storage_role_assignments = merge(
    {
      storage_mta_principal_blob_contributor = {
        principal_id = azuread_service_principal.sflz_storage_mta.object_id
        role_name    = "Storage Blob Data Contributor"
        description  = "Grant blob access to the storage integration service principal on the external stage storage account"
      }
      deployment_principal_storage_blob_contributor = {
        principal_id = local.config.projects.azhubs.client.service_principal.object_id
        role_name    = "Storage Blob Data Contributor"
        description  = "Grant blob data to deployment principal on the external stage storage account"
      }
      external_stage_system_topic = {
        principal_id = azurerm_eventgrid_system_topic.sflz_external_stage_topic.identity[0].principal_id
        role_name    = "Storage Queue Data Message Sender"
        description  = "Grant send messages permission to Event Grid System Topic to send messages to the notification queue"
      }
    },
    local.notification_integration_client_id == null ? {} : {
      notification_mta_principal_queue_contributor = {
        principal_id = azuread_service_principal.sflz_notification_mta[0].object_id
        role_name    = "Storage Queue Data Contributor"
        description  = "Grant queue access to the notification integration service principal on the external stage storage account"
      }
    }
  )
}
