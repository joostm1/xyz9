terraform {
  backend "azurerm" {
    resource_group_name  = ""
    storage_account_name = ""
    subscription_id      = ""
    tenant_id            = ""
    use_azuread_auth     = true
  }
  required_providers {
    azapi = {
      source = "Azure/azapi"
    }
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
  client_certificate              = data.azurerm_key_vault_secret.owner_p12.value
  resource_provider_registrations = "extended"
  use_cli                         = false
  features {
    key_vault {
      purge_soft_delete_on_destroy    = true
      recover_soft_deleted_key_vaults = true
    }
  }
}
provider "snowflake" {
  organization_name        = split("-", lower(data.azurerm_key_vault_secret.snowflake["snowflake-account-identifier"].value))[0]
  account_name             = split("-", lower(data.azurerm_key_vault_secret.snowflake["snowflake-account-identifier"].value))[1]
  user                     = lower(local.config.snowflake.provisioner_username)
  authenticator            = "SNOWFLAKE_JWT"
  private_key              = data.azurerm_key_vault_secret.snowflake["snowflake-provisioner-private-key"].value
  role                     = "ACCOUNTADMIN"
  warehouse                = "COMPUTE_WH"
  preview_features_enabled = local.config.snowflake.terraform_provider_preview_features_enabled
  alias                    = "initial"
}
provider "snowflake" {
  organization_name        = split("-", lower(data.azurerm_key_vault_secret.snowflake["snowflake-account-identifier"].value))[0]
  account_name             = split("-", lower(data.azurerm_key_vault_secret.snowflake["snowflake-account-identifier"].value))[1]
  user                     = lower(local.config.snowflake.provisioner_username)
  authenticator            = "SNOWFLAKE_JWT"
  private_key              = data.azurerm_key_vault_secret.snowflake["snowflake-provisioner-private-key"].value
  role                     = "ACCOUNTADMIN"
  warehouse                = "COMPUTE_WH"
  preview_features_enabled = local.config.snowflake.terraform_provider_preview_features_enabled
  alias                    = "accountadmin"
}
provider "snowflake" {
  organization_name        = split("-", lower(data.azurerm_key_vault_secret.snowflake["snowflake-account-identifier"].value))[0]
  account_name             = split("-", lower(data.azurerm_key_vault_secret.snowflake["snowflake-account-identifier"].value))[1]
  user                     = lower(local.config.snowflake.provisioner_username)
  authenticator            = "SNOWFLAKE_JWT"
  private_key              = data.azurerm_key_vault_secret.snowflake["snowflake-provisioner-private-key"].value
  role                     = "SECURITYADMIN"
  warehouse                = "COMPUTE_WH"
  preview_features_enabled = local.config.snowflake.terraform_provider_preview_features_enabled
  alias                    = "securityadmin"
}
provider "snowflake" {
  organization_name        = split("-", lower(data.azurerm_key_vault_secret.snowflake["snowflake-account-identifier"].value))[0]
  account_name             = split("-", lower(data.azurerm_key_vault_secret.snowflake["snowflake-account-identifier"].value))[1]
  user                     = lower(local.config.snowflake.provisioner_username)
  authenticator            = "SNOWFLAKE_JWT"
  private_key              = data.azurerm_key_vault_secret.snowflake["snowflake-provisioner-private-key"].value
  role                     = "SYSADMIN"
  warehouse                = "COMPUTE_WH"
  preview_features_enabled = local.config.snowflake.terraform_provider_preview_features_enabled
  alias                    = "sysadmin"
}
