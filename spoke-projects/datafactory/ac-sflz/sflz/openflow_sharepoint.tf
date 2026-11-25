# Microsoft Graph application id. `Sites.Selected` is an application role on this service principal.
data "azuread_service_principal" "msgraph" {
  count     = local.sharepoint_configured ? 1 : 0
  client_id = "00000003-0000-0000-c000-000000000000"
}
# Create the Entra app for Openflow SharePoint on `az1` and consent `Sites.Selected`. Grant the app on the site itself with `az rest --method post --url https://graph.microsoft.com/v1.0/sites/{hostname}:/sites/{name}:/permissions` and body `{"roles":["read"],"grantedToIdentities":[{"application":{"id":"<client-id>","displayName":"<app-display-name>"}}]}`; use `fullcontrol` when folder ACL changes must not force a reload.
resource "azuread_application" "openflow_sharepoint" {
  count        = local.sharepoint_configured ? 1 : 0
  display_name = "Snowflake ${lower(var.account.identifier)} Openflow SharePoint"
  description  = "Microsoft Graph app for the Openflow SharePoint simple-ingest connector on ${lower(var.account.identifier)}."
  owners       = toset([local.config.projects.azhubs.owner_user.object_id, local.config.projects.azhubs.client.service_principal.object_id])
  required_resource_access {
    resource_app_id = data.azuread_service_principal.msgraph[0].client_id
    resource_access {
      id   = one([for role in data.azuread_service_principal.msgraph[0].app_roles : role.id if role.value == "Sites.Selected"])
      type = "Role"
    }
  }
}
resource "azuread_service_principal" "openflow_sharepoint" {
  count     = local.sharepoint_configured ? 1 : 0
  client_id = azuread_application.openflow_sharepoint[0].client_id
  owners    = toset([local.config.projects.azhubs.owner_user.object_id, local.config.projects.azhubs.client.service_principal.object_id])
}
resource "azuread_app_role_assignment" "openflow_sharepoint_sites_selected" {
  count               = local.sharepoint_configured ? 1 : 0
  app_role_id         = one([for role in data.azuread_service_principal.msgraph[0].app_roles : role.id if role.value == "Sites.Selected"])
  principal_object_id = azuread_service_principal.openflow_sharepoint[0].object_id
  resource_object_id  = data.azuread_service_principal.msgraph[0].object_id
}
resource "azuread_application_password" "openflow_sharepoint" {
  count          = local.sharepoint_configured ? 1 : 0
  application_id = azuread_application.openflow_sharepoint[0].id
  display_name   = "openflow-sharepoint"
}
# Store the Openflow SharePoint client secret in `kv-xyz9-datafactory`
resource "azurerm_key_vault_secret" "openflow_sharepoint" {
  count        = local.sharepoint_configured ? 1 : 0
  name         = "${var.account.name}-openflow-sharepoint-client-secret"
  value        = azuread_application_password.openflow_sharepoint[0].value
  key_vault_id = local.config.roots["ab-sfbootstrap"].project_vault_id
}
resource "snowflake_secret_with_generic_string" "sharepoint" {
  count         = local.sharepoint_configured ? 1 : 0
  name          = local.resource_names.snowflake.openflow.secret
  database      = snowflake_database.openflow[0].name
  schema        = snowflake_schema.openflow_control[0].name
  secret_string = azurerm_key_vault_secret.openflow_sharepoint[0].value
  comment       = "Entra client secret for the Openflow SharePoint connector."
  provider      = snowflake.accountadmin
}
# Egress for the SharePoint connector. HOST_PORT requires a port; the allow list omits it for login.microsoftonline.com and *.svc.ms.
resource "snowflake_network_rule" "sharepoint" {
  count    = local.sharepoint_configured ? 1 : 0
  name     = local.resource_names.snowflake.openflow.network_rule
  database = snowflake_database.openflow[0].name
  schema   = snowflake_schema.openflow_control[0].name
  mode     = "EGRESS"
  type     = "HOST_PORT"
  value_list = toset([
    "${local.sharepoint_host}:443",
    "graph.microsoft.com:443",
    "graph.microsoft.com:80",
    "login.microsoftonline.com:443",
    "*.svc.ms:443",
  ])
  comment  = "Egress hosts for the Openflow SharePoint connector."
  provider = snowflake.accountadmin
}
resource "snowflake_external_access_integration" "sharepoint" {
  count                 = local.sharepoint_configured ? 1 : 0
  name                  = local.resource_names.snowflake.openflow.eai
  enabled               = true
  allowed_network_rules = [snowflake_network_rule.sharepoint[0].fully_qualified_name]
  allowed_authentication_secrets {
    secrets = [snowflake_secret_with_generic_string.sharepoint[0].fully_qualified_name]
  }
  comment  = "External access integration for Openflow runtime SHAREPOINT."
  provider = snowflake.accountadmin
}
resource "snowflake_grant_privileges_to_account_role" "sharepoint_execute_as_eai" {
  count             = local.sharepoint_configured ? 1 : 0
  account_role_name = snowflake_account_role.openflow_execute_as[0].name
  privileges        = ["USAGE"]
  on_account_object {
    object_type = "INTEGRATION"
    object_name = snowflake_external_access_integration.sharepoint[0].name
  }
  provider = snowflake.accountadmin
}
resource "snowflake_grant_privileges_to_account_role" "sharepoint_execute_as_secret" {
  count             = local.sharepoint_configured ? 1 : 0
  account_role_name = snowflake_account_role.openflow_execute_as[0].name
  privileges        = ["USAGE"]
  on_schema_object {
    object_type = "SECRET"
    object_name = snowflake_secret_with_generic_string.sharepoint[0].fully_qualified_name
  }
  provider = snowflake.accountadmin
}
# Create destination database `SHAREPOINT` for files ingested from SharePoint
resource "snowflake_database" "sharepoint" {
  count    = local.sharepoint_configured ? 1 : 0
  name     = local.resource_names.snowflake.openflow.destination_database
  comment  = "SharePoint files ingested by Openflow."
  provider = snowflake.sysadmin
}
resource "snowflake_schema" "sharepoint_ingest" {
  count    = local.sharepoint_configured ? 1 : 0
  name     = local.resource_names.snowflake.openflow.destination_schema
  database = snowflake_database.sharepoint[0].name
  comment  = "SharePoint simple-ingest destination schema."
  provider = snowflake.sysadmin
}
resource "snowflake_warehouse" "sharepoint" {
  count          = local.sharepoint_configured ? 1 : 0
  name           = local.resource_names.snowflake.openflow.warehouse
  warehouse_size = "XSMALL"
  auto_suspend   = 60
  auto_resume    = "true"
  comment        = "Warehouse for the Openflow SharePoint connector."
  provider       = snowflake.sysadmin
}
resource "snowflake_grant_privileges_to_account_role" "sharepoint_execute_as_database" {
  count             = local.sharepoint_configured ? 1 : 0
  account_role_name = snowflake_account_role.openflow_execute_as[0].name
  privileges        = ["USAGE"]
  on_account_object {
    object_type = "DATABASE"
    object_name = snowflake_database.sharepoint[0].name
  }
  provider = snowflake.sysadmin
}
resource "snowflake_grant_privileges_to_account_role" "sharepoint_execute_as_schema" {
  count             = local.sharepoint_configured ? 1 : 0
  account_role_name = snowflake_account_role.openflow_execute_as[0].name
  privileges        = ["USAGE", "CREATE TABLE", "CREATE STAGE", "CREATE SEQUENCE"]
  on_schema {
    schema_name = snowflake_schema.sharepoint_ingest[0].fully_qualified_name
  }
  provider = snowflake.sysadmin
}
resource "snowflake_grant_privileges_to_account_role" "sharepoint_execute_as_warehouse" {
  count             = local.sharepoint_configured ? 1 : 0
  account_role_name = snowflake_account_role.openflow_execute_as[0].name
  privileges        = ["USAGE", "OPERATE"]
  on_account_object {
    object_type = "WAREHOUSE"
    object_name = snowflake_warehouse.sharepoint[0].name
  }
  provider = snowflake.securityadmin
}
resource "snowflake_stage_internal" "sharepoint_bundles" {
  count    = local.sharepoint_configured ? 1 : 0
  name     = local.resource_names.snowflake.openflow.stage
  database = snowflake_database.openflow[0].name
  schema   = snowflake_schema.openflow_control[0].name
  comment  = "Configuration bundle for the Openflow SharePoint connector."
  provider = snowflake.accountadmin
}
resource "local_file" "sharepoint_config" {
  count    = local.sharepoint_configured && local.sharepoint_definition_name != null ? 1 : 0
  filename = "${path.module}/generated/sharepoint-config.json"
  content = jsonencode({
    configFormatVersion   = 1
    connectorDefinitionId = local.sharepoint_definition_name
    configuration = [
      {
        name = "SharePoint (Simple Ingest, No ACL) Source Parameters"
        properties = {
          "SharePoint Site URL"      = { valueType = "STRING_LITERAL", value = local.sharepoint.site_url }
          "SharePoint Client ID"     = { valueType = "STRING_LITERAL", value = azuread_application.openflow_sharepoint[0].client_id }
          "SharePoint Tenant ID"     = { valueType = "STRING_LITERAL", value = var.tenant_id }
          "SharePoint Client Secret" = { valueType = "SECRET_REFERENCE", fullyQualifiedSecretName = snowflake_secret_with_generic_string.sharepoint[0].fully_qualified_name }
        }
      },
      {
        name = "SharePoint (Simple Ingest, No ACL) Destination Parameters"
        properties = {
          "Destination Database"              = { valueType = "STRING_LITERAL", value = snowflake_database.sharepoint[0].name }
          "Destination Schema"                = { valueType = "STRING_LITERAL", value = snowflake_schema.sharepoint_ingest[0].name }
          "Snowflake Authentication Strategy" = { valueType = "STRING_LITERAL", value = "SNOWFLAKE_MANAGED" }
          "Snowflake Account Identifier"      = { valueType = "STRING_LITERAL", value = "" }
          "Snowflake Username"                = { valueType = "STRING_LITERAL", value = "" }
          "Snowflake Role"                    = { valueType = "STRING_LITERAL", value = snowflake_account_role.openflow_execute_as[0].name }
          "Snowflake Warehouse"               = { valueType = "STRING_LITERAL", value = snowflake_warehouse.sharepoint[0].name }
        }
      },
      {
        name = "SharePoint (Simple Ingest, No ACL) Ingestion Parameter"
        properties = {
          "SharePoint Document Library Name" = { valueType = "STRING_LITERAL", value = local.sharepoint.document_library }
          "SharePoint Source Folder"         = { valueType = "STRING_LITERAL", value = local.sharepoint.source_folder }
        }
      },
    ]
  })
}
resource "terraform_data" "sharepoint_definition" {
  count = local.sharepoint_configured && local.sharepoint_definition_name != null ? 1 : 0
  lifecycle {
    precondition {
      condition     = local.sharepoint_definition_name != null
      error_message = "SHOW OPENFLOW CONNECTOR DEFINITIONS has no display_name \"Microsoft SharePoint (Simple Ingest, no document ACLs)\"."
    }
  }
}
resource "snowflake_execute" "sharepoint_config" {
  count    = local.sharepoint_configured && local.sharepoint_definition_name != null ? 1 : 0
  execute  = "PUT file://${local_file.sharepoint_config[0].filename} @${snowflake_stage_internal.sharepoint_bundles[0].fully_qualified_name}/sharepoint/ AUTO_COMPRESS = FALSE OVERWRITE = TRUE"
  revert   = "REMOVE @${snowflake_stage_internal.sharepoint_bundles[0].fully_qualified_name}/sharepoint/config.json"
  provider = snowflake.accountadmin
}
# Create connector `SHAREPOINT` from the staged bundle. It stays stopped until someone starts it in the Openflow UI, after the site permission exists.
resource "snowflake_openflow_connector" "sharepoint" {
  count    = local.sharepoint_configured && local.sharepoint_definition_name != null ? 1 : 0
  database = snowflake_database.openflow[0].name
  schema   = snowflake_schema.openflow_control[0].name
  name     = local.resource_names.snowflake.openflow.connector
  runtime  = snowflake_openflow_runtime.sharepoint[0].fully_qualified_name
  from {
    stage = snowflake_stage_internal.sharepoint_bundles[0].fully_qualified_name
    path  = "sharepoint"
  }
  version_trigger = local_file.sharepoint_config[0].content_sha256
  comment         = "Microsoft SharePoint simple ingest, no document ACLs."
  provider        = snowflake.accountadmin
  timeouts {
    create = "45m"
    update = "45m"
    delete = "45m"
  }
  depends_on = [
    snowflake_execute.sharepoint_config,
    snowflake_grant_privileges_to_account_role.sharepoint_execute_as_eai,
    snowflake_grant_privileges_to_account_role.sharepoint_execute_as_secret,
    snowflake_grant_privileges_to_account_role.sharepoint_execute_as_database,
    snowflake_grant_privileges_to_account_role.sharepoint_execute_as_schema,
    snowflake_grant_privileges_to_account_role.sharepoint_execute_as_warehouse,
    terraform_data.sharepoint_definition,
  ]
}
