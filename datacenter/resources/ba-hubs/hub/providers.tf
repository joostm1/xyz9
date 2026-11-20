terraform {
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
    cloudflare = {
      source = "cloudflare/cloudflare"
    }
    cloudinit = {
      source = "hashicorp/cloudinit"
    }
    archive = {
      source = "hashicorp/archive"
    }
    tls = {
      source = "hashicorp/tls"
    }
  }
}
