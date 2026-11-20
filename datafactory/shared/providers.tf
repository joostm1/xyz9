# backend + Azure/Snowflake provider aliases (accountadmin/securityadmin/sysadmin/useradmin)
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
    azuread = {
      source = "hashicorp/azuread"
    }
    snowflake = {
      source = "snowflakedb/snowflake"
    }
    azapi = {
      source = "azure/azapi"
    }
    external = {
      source = "hashicorp/external"
    }
    time = {
      source = "hashicorp/time"
    }
    tls = {
      source = "hashicorp/tls"
    }
    random = {
      source = "hashicorp/random"
    }
    azuredevops = {
      source = "microsoft/azuredevops"
    }
    cloudflare = {
      source = "cloudflare/cloudflare"
    }
  }
}
# azurerm provider using Azure CLI authentication
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
  subscription_id                 = local.config.projects.projects.azurerm.subscription.id
  client_id                       = local.config.projects.projects.identity.owner.app_client_id
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
provider "azuread" {
  tenant_id          = var.tenant_id
  client_id          = local.config.projects.projects.identity.owner.app_client_id
  client_certificate = data.azurerm_key_vault_secret.owner_p12.value
  use_cli            = false
}
provider "azapi" {
  tenant_id          = var.tenant_id
  subscription_id    = local.config.projects.projects.azurerm.subscription.id
  client_id          = local.config.projects.projects.identity.owner.app_client_id
  client_certificate = data.azurerm_key_vault_secret.owner_p12.value
}
provider "azuredevops" {
  org_service_url    = "https://dev.azure.com/${local.org.suppliers.msft.devops.org_name}"
  tenant_id          = var.tenant_id
  client_id          = local.config.projects.projects.identity.owner.app_client_id
  client_certificate = data.azurerm_key_vault_secret.owner_p12.value
}
provider "snowflake" {
  organization_name        = split("-", lower(data.azurerm_key_vault_secret.snowflake["snowflake-account-identifier"].value))[0]
  account_name             = split("-", lower(data.azurerm_key_vault_secret.snowflake["snowflake-account-identifier"].value))[1]
  user                     = lower(local.config.roots["am-sfbootstrap"].provisioner.user)
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
  user                     = lower(local.config.roots["am-sfbootstrap"].provisioner.user)
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
  user                     = lower(local.config.roots["am-sfbootstrap"].provisioner.user)
  authenticator            = "SNOWFLAKE_JWT"
  private_key              = data.azurerm_key_vault_secret.snowflake["snowflake-provisioner-private-key"].value
  role                     = "SYSADMIN"
  warehouse                = "COMPUTE_WH"
  preview_features_enabled = local.config.snowflake.terraform_provider_preview_features_enabled
  alias                    = "sysadmin"
}
provider "snowflake" {
  organization_name        = split("-", lower(data.azurerm_key_vault_secret.snowflake["snowflake-account-identifier"].value))[0]
  account_name             = split("-", lower(data.azurerm_key_vault_secret.snowflake["snowflake-account-identifier"].value))[1]
  user                     = lower(local.config.roots["am-sfbootstrap"].provisioner.user)
  authenticator            = "SNOWFLAKE_JWT"
  private_key              = data.azurerm_key_vault_secret.snowflake["snowflake-provisioner-private-key"].value
  role                     = "USERADMIN"
  warehouse                = "COMPUTE_WH"
  preview_features_enabled = local.config.snowflake.terraform_provider_preview_features_enabled
  alias                    = "useradmin"
}
provider "cloudflare" {
  api_token = data.azurerm_key_vault_secret.dc_secrets["cloudflare-dns-editzonekey"].value
}
