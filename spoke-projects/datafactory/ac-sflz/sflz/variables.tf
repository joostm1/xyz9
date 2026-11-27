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
variable "scim_pat" {
  type      = string
  sensitive = true
}
locals {
  config  = var.config
  project = var.project
  resource_names = {
    az = {
      ext_stage            = "sa${local.project.name}${var.account.name}stage"
      int_stage_pe_blob    = "pe-int-stage-blob-${var.account.name}"
      resource_group       = "rg-${local.project.name}"
      sf_pvlinksvc_pe      = "pe-snowflake-service-${var.account.name}"
      storage_queue        = "notifications"
      storage_system_topic = "st-sa-${var.account.name}"
      subnet               = "sn1"
      vnet                 = "vn1"
    }
    snowflake = {
      service_urls = {
        public = {
          svc = "snowflakecomputing.com"
          app = "snowflake.app"
        }
        private = {
          svc = "privatelink.snowflakecomputing.com"
          app = "privatelink.snowflake.app"
        }
      }
      location_id = {
        west-europe = "amszqu"
      }
      storage_integration         = upper("INT_STORAGE_sa${local.project.name}")
      notification_integration    = upper("INT_NOTIFICATION_sa${local.project.name}")
      sso_integration             = "INT_SECURITY_SAML_SSO"
      sso_integration_privatelink = "INT_SECURITY_SAML_SSO_PRIVATELINK"
      dbt_cloud_external_oauth    = "INT_SECURITY_EXTERNAL_OAUTH_DBT_CLOUD"
      scim_external_oauth         = "EXTERNAL_OAUTH_FOR_SCIM"
      scim_integration            = "INT_SECURITY_SCIM"
      scim_provisioner_role       = var.account.scim.provisioner_role
      scim_service_user           = var.account.scim.service_user
      openflow = {
        admin_role           = "OPENFLOW_ADMIN"
        execute_as_role      = "OPENFLOW_SHAREPOINT_EXECUTE_AS_RL"
        database             = "OPENFLOW"
        schema               = "CONTROL"
        deployment           = "OPENFLOW"
        runtime              = "SHAREPOINT"
        destination_database = "SHAREPOINT"
        destination_schema   = "INGEST"
        warehouse            = "SHAREPOINT"
        network_rule         = "OPENFLOW_SHAREPOINT_NETWORK_RULE"
        eai                  = "OPENFLOW_SHAREPOINT_EAI"
        secret               = "SHAREPOINT_CLIENT_SECRET"
        stage                = "CONNECTOR_BUNDLES"
        connector            = "SHAREPOINT"
      }
    }
  }
  openflow_enabled      = var.account.name == "az1"
  sharepoint            = try(var.project.snowflake.openflow.sharepoint, null)
  sharepoint_configured = local.openflow_enabled && try(local.sharepoint.site_url, "") != "" && try(local.sharepoint.document_library, "") != ""
  sharepoint_definitions = local.openflow_enabled ? [
    for item in data.snowflake_openflow_connector_definitions.sharepoint[0].openflow_connector_definitions : item.show_output[0]
    if try(item.show_output[0].display_name, "") == "Microsoft SharePoint (Simple Ingest, no document ACLs)"
  ] : []
  sharepoint_definition_name = try(local.sharepoint_definitions[0].name, null)
  sharepoint_min_node_type   = upper(try(local.sharepoint_definitions[0].min_runtime_node_type, "SMALL"))
  openflow_node_type         = contains(["SMALL", "MEDIUM", "LARGE"], local.sharepoint_min_node_type) ? local.sharepoint_min_node_type : "SMALL"
  sharepoint_host            = local.sharepoint_configured ? regex("^https://([^/]+)", local.sharepoint.site_url)[0] : null
  scim_endpoint_id           = try(snowflake_execute.snowflake_entraid_scim_endpoint[0].query_results[0].scim_endpoint_id, null)
}
