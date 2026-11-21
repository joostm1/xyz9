# private connectivity into Snowflake: internal stage + Snowflake service PE and DNS
# ENABLE_INTERNAL_STAGES_PRIVATELINK is set in am-sfbootstrap
data "snowflake_system_get_privatelink_config" "snowflake_private_link" {
  provider = snowflake.accountadmin
}
# disable public access on internal stage storage account, might collide with dbt [cloud] at some point
resource "snowflake_execute" "disable_internal_stage_public_access" {
  execute  = <<-EOT
    SELECT SYSTEM$BLOCK_INTERNAL_STAGES_PUBLIC_ACCESS()
  EOT
  revert   = <<-EOT
    SELECT SYSTEM$UNBLOCK_INTERNAL_STAGES_PUBLIC_ACCESS()
  EOT
  provider = snowflake.accountadmin
}
# --- internal stage PE in our VNet (approve at snowflake's end) ---
module "pe_internal_stage_blob" {
  source                      = "../../../../aa-catalog/catalog/terraform/modules/az/private_endpoint"
  private_connection_resource = data.snowflake_system_get_privatelink_config.snowflake_private_link.internal_stage
  location                    = local.config.projects.datacenter.spoke.rg.location
  name                        = local.resource_names.az.int_stage_pe_blob
  resource_group_name         = local.config.projects.datacenter.spoke.rg.name
  sub_resources               = ["blob"]
  subnet_id                   = local.config.projects.datacenter.spoke.vnet.vn1.subnets.sn1.id
  is_manual_connection        = true
}
resource "snowflake_execute" "sflz_internal_stage_approve_private_link" {
  execute  = "SELECT SYSTEM$AUTHORIZE_STAGE_PRIVATELINK_ACCESS('${module.pe_internal_stage_blob.id}');"
  revert   = "SELECT SYSTEM$REVOKE_STAGE_PRIVATELINK_ACCESS('${module.pe_internal_stage_blob.id}');"
  provider = snowflake.accountadmin
}
# --- Snowflake service PE in our VNet (approve at snowflake's end) ---
resource "azurerm_private_endpoint" "pe_sflz_pvlinksvc" {
  name                          = local.resource_names.az.sf_pvlinksvc_pe
  location                      = local.config.projects.datacenter.spoke.rg.location
  resource_group_name           = local.config.projects.datacenter.spoke.rg.name
  subnet_id                     = local.config.projects.datacenter.spoke.vnet.vn1.subnets.sn1.id
  custom_network_interface_name = "${local.resource_names.az.sf_pvlinksvc_pe}-nic"
  private_service_connection {
    name                              = "${local.resource_names.az.sf_pvlinksvc_pe}-psc"
    private_connection_resource_alias = data.snowflake_system_get_privatelink_config.snowflake_private_link.azure_pls_id
    is_manual_connection              = true
    request_message                   = "Please approve this private link connection."
  }
  private_dns_zone_group {
    name                 = "${local.resource_names.az.sf_pvlinksvc_pe}-pdnszg"
    private_dns_zone_ids = ["/subscriptions/98000b13-b691-416e-ad86-ef05d9227b9e/resourceGroups/rg-datacenter/providers/Microsoft.Network/privateDnsZones/privatelink.snowflakecomputing.com"]
  }
}
# get an access token for the snowflake private link approval call
module "sflz_azure_access_token" {
  source     = "../../../../aa-catalog/catalog/terraform/modules/entra/acquire_token_for_client"
  tenant_id  = var.tenant_id
  client_id  = local.config.projects.projects.identity.owner.app_client_id
  p12_bundle = data.azurerm_key_vault_secret.owner_p12.value
  scopes     = ["https://management.azure.com/.default"]
}
resource "snowflake_execute" "pe_sflz_snowflake_service_approve_private_link" {
  execute  = "SELECT SYSTEM$AUTHORIZE_PRIVATELINK('${azurerm_private_endpoint.pe_sflz_pvlinksvc.id}','${module.sflz_azure_access_token.access_token}');"
  revert   = "SELECT 1" # accessToken expires and is not refreshed at "revert" time
  provider = snowflake.accountadmin
  lifecycle {
    ignore_changes = [execute] # token is ephemeral; don't trigger updates when it expires
  }
}
# --- private DNS for Snowflake service URLs ---
# dns A record for the account url, i.e.,  nq83813.west-europe.privatelink.snowflakecomputing.com IN A <private-ip>
resource "azurerm_private_dns_a_record" "pe_sflz_snowflake_service_dns_a_record" {
  name                = replace(data.snowflake_system_get_privatelink_config.snowflake_private_link.account_url, ".${local.resource_names.snowflake.private_service_urls.svc}", "")
  private_dns_zone_id = "/subscriptions/98000b13-b691-416e-ad86-ef05d9227b9e/resourceGroups/rg-datacenter/providers/Microsoft.Network/privateDnsZones/${local.resource_names.snowflake.private_service_urls.svc}"
  ttl                 = 300
  records             = [azurerm_private_endpoint.pe_sflz_pvlinksvc.private_service_connection[0].private_ip_address]
}
# snowflakecomputing.com aliases as CNAMEs to _the_ A record
resource "azurerm_private_dns_cname_record" "privatelink_snowflake_svc" {
  for_each = {
    regionless_account_url   = replace(data.snowflake_system_get_privatelink_config.snowflake_private_link.regionless_account_url, ".${local.resource_names.snowflake.private_service_urls.svc}", "")
    ocsp_url                 = replace(data.snowflake_system_get_privatelink_config.snowflake_private_link.ocsp_url, ".${local.resource_names.snowflake.private_service_urls.svc}", "")
    regionless_snowsight_url = replace(data.snowflake_system_get_privatelink_config.snowflake_private_link.regionless_snowsight_url, ".${local.resource_names.snowflake.private_service_urls.svc}", "")
    snowsight_url            = replace(data.snowflake_system_get_privatelink_config.snowflake_private_link.snowsight_url, ".${local.resource_names.snowflake.private_service_urls.svc}", "")
    spcs_auth_url            = "sfc-endpoint-login.${local.resource_names.snowflake.location_id.west-europe}"
    spcs_registry_url        = "${lower(data.azurerm_key_vault_secret.snowflake["snowflake-account-identifier"].value)}.registry"
    openflow_url             = "${lower(data.azurerm_key_vault_secret.snowflake["snowflake-account-identifier"].value)}.openflow.${local.resource_names.snowflake.location_id.west-europe}"
  }
  private_dns_zone_id = "/subscriptions/98000b13-b691-416e-ad86-ef05d9227b9e/resourceGroups/rg-datacenter/providers/Microsoft.Network/privateDnsZones/${local.resource_names.snowflake.private_service_urls.svc}"
  name                = each.value
  ttl                 = 300
  record              = azurerm_private_dns_a_record.pe_sflz_snowflake_service_dns_a_record.fqdn
}
# snowflake.app aliases as CNAMEs to _the_ A record
resource "azurerm_private_dns_cname_record" "privatelink_snowflake_app" {
  for_each = {
    app_service = "*.amszqu" # app-service-privatelink-url
  }
  name                = each.value
  private_dns_zone_id = "/subscriptions/98000b13-b691-416e-ad86-ef05d9227b9e/resourceGroups/rg-datacenter/providers/Microsoft.Network/privateDnsZones/${local.resource_names.snowflake.private_service_urls.app}"
  ttl                 = 300
  record              = azurerm_private_dns_a_record.pe_sflz_snowflake_service_dns_a_record.fqdn
}
