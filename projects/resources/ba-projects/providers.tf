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
    azuredevops = {
      source = "microsoft/azuredevops"
    }
    tls = {
      source = "hashicorp/tls"
    }
    pkcs12 = {
      source = "chilicat/pkcs12"
    }
  }
}
# azurerm provider using az cli authentication
provider "azurerm" {
  storage_use_azuread             = true
  tenant_id                       = var.tenant_id
  resource_provider_registrations = "none"
  subscription_id                 = split("/", var.corp_vault_id)[2]
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
  subscription_id                 = local.config.roots["aa-self"].azurerm.project.subscription.id
  client_id                       = local.config.roots["aa-self"].identity.owner.app_client_id
  client_certificate              = data.azurerm_key_vault_secret.config_owner_p12.value
  resource_provider_registrations = "extended"
  use_cli                         = false
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
  subscription_id                 = split("/", var.corp_vault_id)[2]
  client_id                       = local.config.roots["aa-self"].identity.owner.app_client_id
  client_certificate              = data.azurerm_key_vault_secret.config_owner_p12.value
  resource_provider_registrations = "extended"
  alias                           = "iac"
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
  client_id          = local.config.roots["aa-self"].identity.owner.app_client_id
  client_certificate = data.azurerm_key_vault_secret.config_owner_p12.value
  use_cli            = false
}
provider "azuredevops" {
  org_service_url    = "https://dev.azure.com/${local.org.suppliers.msft.devops.org_name}"
  tenant_id          = var.tenant_id
  client_id          = local.config.roots["aa-self"].identity.owner.app_client_id
  client_certificate = data.azurerm_key_vault_secret.config_owner_p12.value
}
