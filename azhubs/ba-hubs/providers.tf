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
    tls = {
      source = "hashicorp/tls"
    }
    archive = {
      source = "hashicorp/archive"
    }
    cloudflare = {
      source = "cloudflare/cloudflare"
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
      recover_soft_deleted_key_vaults = false
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
      recover_soft_deleted_key_vaults = false
    }
  }
}
provider "azuread" {
  tenant_id          = var.tenant_id
  client_id          = local.config.projects.projects.identity.owner.app_client_id
  client_certificate = data.azurerm_key_vault_secret.owner_p12.value
  use_cli            = false
}
provider "cloudflare" {
  api_token = var.cloudflare_api_token != "" ? var.cloudflare_api_token : data.azurerm_key_vault_secret.dc_secrets["cloudflare-dns-editzonekey"].value
}
