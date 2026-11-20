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
    cloudflare = {
      source = "cloudflare/cloudflare"
    }
    azuredevops = {
      source = "microsoft/azuredevops"
    }
    external = {
      source = "hashicorp/external"
    }
    acme = {
      source = "vancluever/acme"
    }
    tls = {
      source = "hashicorp/tls"
    }
    docker = {
      source = "kreuzwerker/docker"
    }
    local = {
      source = "hashicorp/local"
    }
    archive = {
      source = "hashicorp/archive"
    }
    pkcs12 = {
      source = "chilicat/pkcs12"
    }
    random = {
      source = "hashicorp/random"
    }
  }
}
provider "pkcs12" {}
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
# Signed-in user. The homeapps repo creates the OPI backup app as that user.
provider "azuread" {
  tenant_id = var.tenant_id
  use_cli   = true
}
provider "cloudflare" {
  api_token = data.azurerm_key_vault_secret.sp1_secrets["cloudflare-dns-editzonekey"].value
}
provider "acme" {
  server_url = "https://acme-staging-v02.api.letsencrypt.org/directory"
  alias      = "staging"
}
provider "acme" {
  server_url = "https://acme-v02.api.letsencrypt.org/directory"
}
# azurerm.corp already uses the Azure CLI. This provider follows that session.
provider "azuredevops" {
  org_service_url = "https://dev.azure.com/${local.org.suppliers.msft.devops.org_name}"
  use_cli         = true
}
