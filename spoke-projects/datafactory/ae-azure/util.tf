# util storage: SHIR Run Command logs and other non-stage blobs (not Snowflake ingest)
resource "azurerm_storage_account" "util" {
  name                            = local.resource_names.az.util
  resource_group_name             = local.config.projects.azhubs.spoke.rg.name
  location                        = local.config.projects.azhubs.spoke.rg.location
  allow_nested_items_to_be_public = false
  default_to_oauth_authentication = true
  account_kind                    = "StorageV2"
  account_tier                    = "Standard"
  account_replication_type        = "LRS"
  is_hns_enabled                  = false # hns_failed = true though
  min_tls_version                 = "TLS1_2"
  public_network_access           = "Enabled"
  shared_access_key_enabled       = false
  network_rules {
    default_action = "Allow"
    bypass         = ["AzureServices"]
  }
  blob_properties {
    versioning_enabled = true
  }
}
# spoke blob DNS; the SHIR VM uploads Run Command stdout over this endpoint
module "util_pe_blob" {
  source                      = "../../../catalog/terraform/modules/az/private_endpoint"
  name                        = local.resource_names.az.util_pe_blob
  location                    = local.config.projects.azhubs.spoke.rg.location
  resource_group_name         = local.config.projects.azhubs.spoke.rg.name
  subnet_id                   = local.config.projects.azhubs.spoke.vnet.vn1.subnets.sn1.id
  sub_resources               = ["blob"]
  private_connection_resource = azurerm_storage_account.util.id
  dnszoneresourcegroup_id     = local.private_dns_rg_id
}
resource "azurerm_storage_management_policy" "util_retention" {
  storage_account_id = azurerm_storage_account.util.id
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
