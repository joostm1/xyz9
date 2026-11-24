# module inputs; same-project config from ab-sfbootstrap remote_state
variable "state_key" {
  type = string
}
variable "project_name" {
  type = string
}
variable "corp_vault_id" {
  type = string
}
variable "tenant_id" {
  type = string
}
variable "storage_account_name" {
  type = string
}
variable "resource_group_name" {
  type = string
}

locals {
  org     = jsondecode(file("../../../catalog/org.json"))
  project = jsondecode(file("../../../catalog/projects/${var.project_name}.json"))
  # our predecessor
  config = data.terraform_remote_state.am_sfbootstrap.outputs.config
  # private DNS zones are in the same resource group as kv-xyz9-azhubs
  private_dns_rg_id = regex("^/subscriptions/[^/]+/resourceGroups/[^/]+", local.config.projects.azhubs.vault.id)
  resource_names = {
    az = {
      ext_stage            = "sa${local.project.name}stage"
      int_stage_pe_blob    = "pe-int-stage-blob"
      resource_group       = "rg-${local.project.name}"
      sf_pvlinksvc_pe      = "pe-snowflake-service"
      storage_queue        = "notifications"
      storage_system_topic = "st-sa"
      subnet               = "sn1"
      vnet                 = "vn1"
    }
    snowflake = {
      service_urls = {
        svc = "snowflakecomputing.com"
        app = "snowflake.app"
      }
      private_service_urls = {
        svc = "privatelink.snowflakecomputing.com"
        app = "privatelink.snowflake.app"
      }
      location_id = {
        west-europe = "amszqu"
      }
      storage_integration      = upper("INT_STORAGE_sa${local.project.name}")
      notification_integration = upper("INT_NOTIFICATION_sa${local.project.name}")
      sso_integration          = "INT_SECURITY_SAML_SSO"
      dbt_cloud_external_oauth = "INT_SECURITY_EXTERNAL_OAUTH_DBT_CLOUD"
      scim_external_oauth      = "EXTERNAL_OAUTH_FOR_SCIM"
      scim_integration         = "INT_SECURITY_SCIM"
      scim_provisioner_role    = local.config.roots["ab-sfbootstrap"].scim.provisioner_role
      scim_service_user        = local.config.roots["ab-sfbootstrap"].scim.service_user
    }
  }
  # snowflake_execute.query is empty at first plan; one()/[0] would crash
  # azapi_resource_list exports {name, private_endpoint_id}; null until Snowflake's id shows up on the account
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
  # SHOW uses the seed name so query_results is known at plan (not deferred on the integration resource)
  scim_integration_present = length(snowflake_execute.snowflake_entraid_scim_present.query_results) > 0
  scim_endpoint_id         = try(snowflake_execute.snowflake_entraid_scim_endpoint[0].query_results[0].scim_endpoint_id, null)
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
