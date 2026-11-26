# external stage path: Azure storage/queue, integrations, and privatelink at snowflake's end
# --- Azure landing surface ---
resource "azurerm_storage_account" "sflz_external_stage" {
  name                            = local.resource_names.az.ext_stage
  resource_group_name             = local.config.projects.azhubs.spoke.rg.name
  location                        = local.config.projects.azhubs.spoke.rg.location
  allow_nested_items_to_be_public = false
  default_to_oauth_authentication = true
  account_kind                    = "StorageV2"
  account_tier                    = "Standard"
  account_replication_type        = "LRS"
  is_hns_enabled                  = false # invalidates versioning and Snowflake doesn't support it: hns_failed = true
  min_tls_version                 = "TLS1_2"
  public_network_access           = "Enabled"
  shared_access_key_enabled       = false # defaults to true, shocking
  network_rules {
    default_action = "Deny"
    bypass         = ["AzureServices"] # required for event grid system topic to send messages to the storage queue
  }
  blob_properties {
    versioning_enabled = true
  }
}
resource "azurerm_storage_management_policy" "sflz_external_stage_retention" {
  storage_account_id = azurerm_storage_account.sflz_external_stage.id
  rule {
    name    = "retain-blob-versions-7-days"
    enabled = true
    filters {
      blob_types = ["blockBlob"]
    }
    actions {
      version {
        delete_after_days_since_creation = 7
      }
    }
  }
}
# storage queue in the external stage account for notification integration
resource "azurerm_storage_queue" "sflz_notification_queue" {
  name               = local.resource_names.az.storage_queue
  storage_account_id = azurerm_storage_account.sflz_external_stage.id
}
# --- storage integration + privatelink at snowflake's end (blob) ---
# https://docs.snowflake.com/en/user-guide/data-load-azure-private
# accountadmin: CREATE INTEGRATION is account-scoped; SYSADMIN only receives USAGE afterwards
# in-place ALTER of locations and privatelink, so the consent URL is not replaced when a container is added
resource "snowflake_storage_integration_azure" "sflz" {
  name                      = local.resource_names.snowflake.storage_integration
  enabled                   = true
  azure_tenant_id           = var.tenant_id
  storage_allowed_locations = [for c in azurerm_storage_container.layer : "azure://${azurerm_storage_account.sflz_external_stage.name}.blob.core.windows.net/${c.name}"]
  use_privatelink_endpoint  = local.ext_stage_blob_pe_connection != null ? "true" : "false"
  depends_on                = [terraform_data.approve_sf_end_ext_stage_blob]
  provider                  = snowflake.accountadmin
}
# service principal for the storage integration app
# owners recorded once; backing app is not in this tenant, so later owner updates are ignored
resource "azuread_service_principal" "sflz_storage_mta" {
  client_id = local.storage_integration_client_id
  owners = toset([
    local.config.projects.azhubs.owner_user.object_id,
    local.config.projects.azhubs.client.service_principal.object_id,
  ])
  lifecycle {
    ignore_changes = [owners] # owner app cannot mutate multi-tenant Snowflake SPs
  }
}
# GET_PRIVATELINK_ENDPOINTS_INFO returns a JSON array of stringified endpoint objects
# DISCONNECTED cannot be repaired in place. Deprovision it; Snowflake blocks a replacement for 7 days.
resource "snowflake_execute" "external_stage_private_endpoint" {
  execute  = <<-EOT
    EXECUTE IMMEDIATE $$
    DECLARE
      v_state STRING;
      v_status STRING;
      deleting_endpoint EXCEPTION (-20002, 'outbound private endpoint is DELETING; Snowflake keeps it for 7 days and has no purge');
      failed_endpoint EXCEPTION (-20003, 'outbound private endpoint is FAILED; ask Snowflake support to clear it before provisioning again');
      unexpected_endpoint EXCEPTION (-20004, 'outbound private endpoint is in an unexpected state; refusing to provision');
    BEGIN
      v_state := (
        SELECT PARSE_JSON(f.value::string):endpoint_state::string
        FROM TABLE(FLATTEN(INPUT => PARSE_JSON(SYSTEM$GET_PRIVATELINK_ENDPOINTS_INFO()))) f
        WHERE LOWER(PARSE_JSON(f.value::string):provider_resource_id::string) = LOWER('${azurerm_storage_account.sflz_external_stage.id}')
          AND PARSE_JSON(f.value::string):subresource::string = 'blob'
        ORDER BY IFF(PARSE_JSON(f.value::string):endpoint_state::string IN ('CREATED', 'PENDING_CREATION'), 0, 1)
        LIMIT 1
      );
      v_status := (
        SELECT PARSE_JSON(f.value::string):status::string
        FROM TABLE(FLATTEN(INPUT => PARSE_JSON(SYSTEM$GET_PRIVATELINK_ENDPOINTS_INFO()))) f
        WHERE LOWER(PARSE_JSON(f.value::string):provider_resource_id::string) = LOWER('${azurerm_storage_account.sflz_external_stage.id}')
          AND PARSE_JSON(f.value::string):subresource::string = 'blob'
        ORDER BY IFF(PARSE_JSON(f.value::string):endpoint_state::string IN ('CREATED', 'PENDING_CREATION'), 0, 1)
        LIMIT 1
      );
      IF (v_state = 'CREATED' AND v_status IN ('DISCONNECTED', 'REJECTED')) THEN
        RETURN SYSTEM$DEPROVISION_PRIVATELINK_ENDPOINT(
          '${azurerm_storage_account.sflz_external_stage.id}',
          'blob'
        );
      ELSEIF (v_state = 'PENDING_DELETION') THEN
        RETURN v_state;
      ELSEIF (v_state IS NULL) THEN
        RETURN SYSTEM$PROVISION_PRIVATELINK_ENDPOINT(
          '${azurerm_storage_account.sflz_external_stage.id}',
          '${azurerm_storage_account.sflz_external_stage.primary_blob_host}',
          'blob'
        );
      ELSEIF (v_state = 'CREATED' OR v_state = 'PENDING_CREATION') THEN
        RETURN v_state;
      ELSEIF (v_state = 'DELETING') THEN
        RAISE deleting_endpoint;
      ELSEIF (v_state = 'FAILED') THEN
        RAISE failed_endpoint;
      ELSE
        RAISE unexpected_endpoint;
      END IF;
    END;
    $$;
  EOT
  revert   = <<-EOT
    EXECUTE IMMEDIATE $$
    DECLARE
      v_state STRING;
    BEGIN
      v_state := (
        SELECT PARSE_JSON(f.value::string):endpoint_state::string
        FROM TABLE(FLATTEN(INPUT => PARSE_JSON(SYSTEM$GET_PRIVATELINK_ENDPOINTS_INFO()))) f
        WHERE LOWER(PARSE_JSON(f.value::string):provider_resource_id::string) = LOWER('${azurerm_storage_account.sflz_external_stage.id}')
          AND PARSE_JSON(f.value::string):subresource::string = 'blob'
          AND PARSE_JSON(f.value::string):endpoint_state::string IN ('CREATED', 'FAILED')
        LIMIT 1
      );
      IF (v_state IS NOT NULL) THEN
        RETURN SYSTEM$DEPROVISION_PRIVATELINK_ENDPOINT(
          '${azurerm_storage_account.sflz_external_stage.id}',
          'blob'
        );
      END IF;
      RETURN 'not deprovisionable';
    END;
    $$;
  EOT
  query    = <<-EOT
    SELECT PARSE_JSON(f.value::string):snowflake_resource_id::string AS "snowflake_resource_id"
    FROM TABLE(FLATTEN(INPUT => PARSE_JSON(SYSTEM$GET_PRIVATELINK_ENDPOINTS_INFO()))) f
    WHERE LOWER(PARSE_JSON(f.value::string):provider_resource_id::string) = LOWER('${azurerm_storage_account.sflz_external_stage.id}')
      AND PARSE_JSON(f.value::string):subresource::string = 'blob'
      AND PARSE_JSON(f.value::string):endpoint_state::string IN ('CREATED', 'PENDING_CREATION')
      AND COALESCE(PARSE_JSON(f.value::string):status::string, 'PENDING') IN ('PENDING', 'APPROVED')
  EOT
  provider = snowflake.accountadmin
}
# Azure lists the private endpoint connection after Snowflake returns its id
resource "time_sleep" "wait_for_ext_stage_blob_pe" {
  create_duration = "60s"
  triggers = {
    private_endpoint_id = try(snowflake_execute.external_stage_private_endpoint.query_results[0].snowflake_resource_id, "none")
  }
}
data "azapi_resource_list" "get_sf_end_ext_stage_blob" {
  type      = "Microsoft.Storage/storageAccounts/privateEndpointConnections@2023-05-01"
  parent_id = azurerm_storage_account.sflz_external_stage.id
  response_export_values = {
    connections = "value[].{name: name, private_endpoint_id: properties.privateEndpoint.id}"
  }
  depends_on = [time_sleep.wait_for_ext_stage_blob_pe]
}
# Approve the blob connection when Azure has registered it. A disconnected endpoint stays queued for 7 days, so this is a no-op until then.
resource "terraform_data" "approve_sf_end_ext_stage_blob" {
  triggers_replace = [try(snowflake_execute.external_stage_private_endpoint.query_results[0].snowflake_resource_id, "none")]
  provisioner "local-exec" {
    command = local.ext_stage_blob_pe_connection == null ? "true" : <<-EOT
      az rest --method put --url "https://management.azure.com${azurerm_storage_account.sflz_external_stage.id}/privateEndpointConnections/${local.ext_stage_blob_pe_connection}?api-version=2023-05-01" --body '{"properties":{"privateLinkServiceConnectionState":{"status":"Approved","description":"Snowflake privatelink at snowflake end (blob)"}}}'
    EOT
  }
}
# --- notification path: queue PE at snowflake's end, then Event Grid + notification integration ---
# provision fails on trial accounts (502055); upgrade billing in Snowsight first
resource "snowflake_execute" "external_stage_queue_private_endpoint" {
  execute  = <<-EOT
    EXECUTE IMMEDIATE $$
    DECLARE
      v_state STRING;
      v_status STRING;
      deleting_endpoint EXCEPTION (-20002, 'outbound private endpoint is DELETING; Snowflake keeps it for 7 days and has no purge');
      failed_endpoint EXCEPTION (-20003, 'outbound private endpoint is FAILED; ask Snowflake support to clear it before provisioning again');
      unexpected_endpoint EXCEPTION (-20004, 'outbound private endpoint is in an unexpected state; refusing to provision');
    BEGIN
      v_state := (
        SELECT PARSE_JSON(f.value::string):endpoint_state::string
        FROM TABLE(FLATTEN(INPUT => PARSE_JSON(SYSTEM$GET_PRIVATELINK_ENDPOINTS_INFO()))) f
        WHERE LOWER(PARSE_JSON(f.value::string):provider_resource_id::string) = LOWER('${azurerm_storage_account.sflz_external_stage.id}')
          AND PARSE_JSON(f.value::string):subresource::string = 'queue'
        ORDER BY IFF(PARSE_JSON(f.value::string):endpoint_state::string IN ('CREATED', 'PENDING_CREATION'), 0, 1)
        LIMIT 1
      );
      v_status := (
        SELECT PARSE_JSON(f.value::string):status::string
        FROM TABLE(FLATTEN(INPUT => PARSE_JSON(SYSTEM$GET_PRIVATELINK_ENDPOINTS_INFO()))) f
        WHERE LOWER(PARSE_JSON(f.value::string):provider_resource_id::string) = LOWER('${azurerm_storage_account.sflz_external_stage.id}')
          AND PARSE_JSON(f.value::string):subresource::string = 'queue'
        ORDER BY IFF(PARSE_JSON(f.value::string):endpoint_state::string IN ('CREATED', 'PENDING_CREATION'), 0, 1)
        LIMIT 1
      );
      IF (v_state = 'CREATED' AND v_status IN ('DISCONNECTED', 'REJECTED')) THEN
        RETURN SYSTEM$DEPROVISION_PRIVATELINK_ENDPOINT(
          '${azurerm_storage_account.sflz_external_stage.id}',
          'queue'
        );
      ELSEIF (v_state = 'PENDING_DELETION') THEN
        RETURN v_state;
      ELSEIF (v_state IS NULL) THEN
        RETURN SYSTEM$PROVISION_PRIVATELINK_ENDPOINT(
          '${azurerm_storage_account.sflz_external_stage.id}',
          '${azurerm_storage_account.sflz_external_stage.primary_queue_host}',
          'queue'
        );
      ELSEIF (v_state = 'CREATED' OR v_state = 'PENDING_CREATION') THEN
        RETURN v_state;
      ELSEIF (v_state = 'DELETING') THEN
        RAISE deleting_endpoint;
      ELSEIF (v_state = 'FAILED') THEN
        RAISE failed_endpoint;
      ELSE
        RAISE unexpected_endpoint;
      END IF;
    END;
    $$;
  EOT
  revert   = <<-EOT
    EXECUTE IMMEDIATE $$
    DECLARE
      v_state STRING;
    BEGIN
      v_state := (
        SELECT PARSE_JSON(f.value::string):endpoint_state::string
        FROM TABLE(FLATTEN(INPUT => PARSE_JSON(SYSTEM$GET_PRIVATELINK_ENDPOINTS_INFO()))) f
        WHERE LOWER(PARSE_JSON(f.value::string):provider_resource_id::string) = LOWER('${azurerm_storage_account.sflz_external_stage.id}')
          AND PARSE_JSON(f.value::string):subresource::string = 'queue'
          AND PARSE_JSON(f.value::string):endpoint_state::string IN ('CREATED', 'FAILED')
        LIMIT 1
      );
      IF (v_state IS NOT NULL) THEN
        RETURN SYSTEM$DEPROVISION_PRIVATELINK_ENDPOINT(
          '${azurerm_storage_account.sflz_external_stage.id}',
          'queue'
        );
      END IF;
      RETURN 'not deprovisionable';
    END;
    $$;
  EOT
  query    = <<-EOT
    SELECT PARSE_JSON(f.value::string):snowflake_resource_id::string AS "snowflake_resource_id"
    FROM TABLE(FLATTEN(INPUT => PARSE_JSON(SYSTEM$GET_PRIVATELINK_ENDPOINTS_INFO()))) f
    WHERE LOWER(PARSE_JSON(f.value::string):provider_resource_id::string) = LOWER('${azurerm_storage_account.sflz_external_stage.id}')
      AND PARSE_JSON(f.value::string):subresource::string = 'queue'
      AND PARSE_JSON(f.value::string):endpoint_state::string IN ('CREATED', 'PENDING_CREATION')
      AND COALESCE(PARSE_JSON(f.value::string):status::string, 'PENDING') IN ('PENDING', 'APPROVED')
  EOT
  provider = snowflake.accountadmin
}
resource "time_sleep" "wait_for_ext_stage_queue_pe" {
  create_duration = "60s"
  triggers = {
    private_endpoint_id = try(snowflake_execute.external_stage_queue_private_endpoint.query_results[0].snowflake_resource_id, "none")
  }
}
data "azapi_resource_list" "get_sf_end_ext_stage_queue" {
  type      = "Microsoft.Storage/storageAccounts/privateEndpointConnections@2023-05-01"
  parent_id = azurerm_storage_account.sflz_external_stage.id
  response_export_values = {
    connections = "value[].{name: name, private_endpoint_id: properties.privateEndpoint.id}"
  }
  depends_on = [time_sleep.wait_for_ext_stage_queue_pe]
}
# Approve the queue connection when Azure has registered it. A disconnected endpoint stays queued for 7 days, so this is a no-op until then.
resource "terraform_data" "approve_sf_end_ext_stage_queue" {
  triggers_replace = [try(snowflake_execute.external_stage_queue_private_endpoint.query_results[0].snowflake_resource_id, "none")]
  provisioner "local-exec" {
    command = local.ext_stage_queue_pe_connection == null ? "true" : <<-EOT
      az rest --method put --url "https://management.azure.com${azurerm_storage_account.sflz_external_stage.id}/privateEndpointConnections/${local.ext_stage_queue_pe_connection}?api-version=2023-05-01" --body '{"properties":{"privateLinkServiceConnectionState":{"status":"Approved","description":"Snowflake privatelink at snowflake end (queue)"}}}'
    EOT
  }
}
# system topic for the external stage storage account
resource "azurerm_eventgrid_system_topic" "sflz_external_stage_topic" {
  name                = local.resource_names.az.storage_system_topic
  resource_group_name = local.config.projects.azhubs.spoke.rg.name
  location            = local.config.projects.azhubs.spoke.rg.location
  source_resource_id  = azurerm_storage_account.sflz_external_stage.id
  topic_type          = "microsoft.storage.storageaccounts"
  identity {
    type = "SystemAssigned"
  }
}
# notification integration — USE_PRIVATELINK_ENDPOINT only at CREATE (no ALTER); recreate may churn consent/SP
resource "snowflake_execute" "notification_integration_azure" {
  count      = 1
  execute    = <<-EOT
    CREATE OR REPLACE NOTIFICATION INTEGRATION ${upper(local.resource_names.snowflake.notification_integration)}
    TYPE = QUEUE
    ENABLED = TRUE
    NOTIFICATION_PROVIDER = AZURE_STORAGE_QUEUE
    AZURE_TENANT_ID = '${var.tenant_id}'
    AZURE_STORAGE_QUEUE_PRIMARY_URI = 'https://${azurerm_storage_account.sflz_external_stage.name}.queue.core.windows.net/${azurerm_storage_queue.sflz_notification_queue.name}'
    USE_PRIVATELINK_ENDPOINT = ${local.ext_stage_queue_pe_connection != null ? "TRUE" : "FALSE"}
  EOT
  revert     = <<-EOT
    DROP NOTIFICATION INTEGRATION IF EXISTS ${local.resource_names.snowflake.notification_integration}
  EOT
  query      = <<-EOT
    DESCRIBE NOTIFICATION INTEGRATION ${local.resource_names.snowflake.notification_integration}
    ->> SELECT
        TRIM(PARSE_URL("property_value"):parameters.client_id, '"') AS "client_id"
    FROM $1
    WHERE "property" = 'AZURE_CONSENT_URL'
  EOT
  depends_on = [terraform_data.approve_sf_end_ext_stage_queue]
  provider   = snowflake.accountadmin
}
# service principal for the notification integration app
# owners recorded once; backing app is not in this tenant, so later owner updates are ignored
resource "azuread_service_principal" "sflz_notification_mta" {
  count     = 1
  client_id = local.notification_integration_client_id
  owners = toset([
    local.config.projects.azhubs.owner_user.object_id,
    local.config.projects.azhubs.client.service_principal.object_id,
  ])
  lifecycle {
    ignore_changes = [owners] # owner app cannot mutate multi-tenant Snowflake SPs
  }
}
# role assignments on the external stage
resource "azurerm_role_assignment" "sflz_storage_role_assignments" {
  for_each             = local.sflz_storage_role_assignments
  principal_id         = each.value.principal_id
  role_definition_name = each.value.role_name
  scope                = azurerm_storage_account.sflz_external_stage.id
}
# one subscription per layer ingest container
resource "azurerm_eventgrid_system_topic_event_subscription" "sflz_external_stage_blob_events" {
  for_each              = azurerm_storage_container.layer
  name                  = "es-${each.value.name}"
  system_topic          = azurerm_eventgrid_system_topic.sflz_external_stage_topic.name
  resource_group_name   = local.config.projects.azhubs.spoke.rg.name
  event_delivery_schema = "EventGridSchema" # Required by SF: https://docs.snowflake.com/en/user-guide/tables-external-azure#supported-accounts-apis-and-schemas
  delivery_identity {
    type = "SystemAssigned" # Use the identity of the topic to deliver the message
  }
  storage_queue_endpoint {
    storage_account_id = azurerm_storage_account.sflz_external_stage.id
    queue_name         = azurerm_storage_queue.sflz_notification_queue.name
  }
  subject_filter {
    subject_begins_with = "/blobServices/default/containers/${each.value.name}"
    case_sensitive      = false
  }
  depends_on = [azurerm_role_assignment.sflz_storage_role_assignments]
}
# service principal for the "Snowflake Workload Identity" app
#  https://docs.snowflake.com/en/user-guide/workload-identity-federation#authenticate-to-snowflake-using-microsoft-idp-and-a-snowflake-python-driver
# no owners: backing app is not in this tenant, so Application.ReadWrite.OwnedBy rejects them on create
resource "azuread_service_principal" "sflz_workload_identity_mta" {
  client_id = "fd3f753b-eed3-462c-b6a7-a4b5bb650aad"
  feature_tags {
    enterprise = true
  }
}
