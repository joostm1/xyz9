terraform {
  backend "azurerm" {
    resource_group_name  = ""
    storage_account_name = ""
    subscription_id      = ""
    tenant_id            = ""
    use_azuread_auth     = true
  }
  required_providers {
    azuredevops = {
      source = "microsoft/azuredevops"
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
  organization_name        = local.azure_snowflake.organization_name
  account_name             = local.azure_snowflake.account_name
  user                     = lower(local.config.snowflake.provisioner_username)
  authenticator            = "SNOWFLAKE_JWT"
  private_key              = data.azurerm_key_vault_secret.snowflake[local.azure_snowflake.provisioner.secret_names.private_key].value
  role                     = "ACCOUNTADMIN"
  warehouse                = "COMPUTE_WH"
  preview_features_enabled = local.config.snowflake.terraform_provider_preview_features_enabled
  alias                    = "initial"
}
provider "azuredevops" {
  org_service_url = "https://dev.azure.com/${local.org.suppliers.msft.devops.org_name}"
}
