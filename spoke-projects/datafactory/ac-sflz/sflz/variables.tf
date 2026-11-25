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
      scim_provisioner_role    = var.account.scim.provisioner_role
      scim_service_user        = var.account.scim.service_user
    }
  }
  scim_integration_present = length(snowflake_execute.snowflake_entraid_scim_present.query_results) > 0
  scim_endpoint_id         = try(snowflake_execute.snowflake_entraid_scim_endpoint[0].query_results[0].scim_endpoint_id, null)
}
