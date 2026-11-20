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
      source  = "hashicorp/azurerm"
      version = "5.14.0"
    }
    acme = {
      source  = "vancluever/acme"
      version = "3.3.1"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "4.4.2"
    }
    archive = {
      source  = "hashicorp/archive"
      version = "2.8.1"
    }
  }
}
# azurerm provider using az cli authentication
provider "azurerm" {
  storage_use_azuread             = true
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
  subscription_id                 = local.config.projects.projects.azurerm.subscription.id # projects contributor
  client_id                       = local.config.projects.projects.identity.owner.app_client_id
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
provider "acme" {
  server_url = "https://acme-staging-v02.api.letsencrypt.org/directory"
  alias      = "staging"
}
provider "acme" {
  server_url = "https://acme-v02.api.letsencrypt.org/directory"
}
