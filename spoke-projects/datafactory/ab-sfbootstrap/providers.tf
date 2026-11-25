terraform {
  backend "azurerm" {
    resource_group_name  = ""
    storage_account_name = ""
    subscription_id      = ""
    tenant_id            = ""
    use_azuread_auth     = true
  }
  required_providers {
    azurerm = {
      source = "hashicorp/azurerm"
    }
    snowflake = {
      source = "snowflakedb/snowflake"
    }
    tls = {
      source = "hashicorp/tls"
    }
    time = {
      source = "hashicorp/time"
    }
  }
}
provider "azurerm" {
  storage_use_azuread             = true
  tenant_id                       = var.tenant_id
  subscription_id                 = split("/", var.corp_vault_id)[2]
  resource_provider_registrations = "none"
  use_cli                         = true
  alias                           = "corp"
  features {
    key_vault {
      purge_soft_delete_on_destroy    = true
      recover_soft_deleted_key_vaults = true
    }
  }
}
provider "azurerm" {
  storage_use_azuread             = true
  tenant_id                       = var.tenant_id
  subscription_id                 = local.config.projects.azhubs.subscription.id
  client_id                       = local.config.projects.azhubs.client.application.client_id
  client_certificate              = data.azurerm_key_vault_secret.client_p12.value
  resource_provider_registrations = "extended"
  use_cli                         = false
  features {
    key_vault {
      purge_soft_delete_on_destroy    = true
      recover_soft_deleted_key_vaults = true
    }
  }
}
# Alias `initial` stays the Azure account `az1` so existing state is not replaced
provider "snowflake" {
  organization_name        = local.snowflake_accounts["az1"].organization_name
  account_name             = local.snowflake_accounts["az1"].account_name
  user                     = lower(local.snowflake_accounts["az1"].username)
  authenticator            = "SNOWFLAKE_JWT"
  private_key              = data.azurerm_key_vault_secret.snowflake_admin_private_key["az1"].value
  role                     = "ACCOUNTADMIN"
  warehouse                = "COMPUTE_WH"
  preview_features_enabled = local.config.snowflake.terraform_provider_preview_features_enabled
  alias                    = "initial"
}
provider "snowflake" {
  organization_name        = local.snowflake_accounts["aw1"].organization_name
  account_name             = local.snowflake_accounts["aw1"].account_name
  user                     = lower(local.snowflake_accounts["aw1"].username)
  authenticator            = "SNOWFLAKE_JWT"
  private_key              = data.azurerm_key_vault_secret.snowflake_admin_private_key["aw1"].value
  role                     = "ACCOUNTADMIN"
  warehouse                = "COMPUTE_WH"
  preview_features_enabled = local.config.snowflake.terraform_provider_preview_features_enabled
  alias                    = "aw1"
}
