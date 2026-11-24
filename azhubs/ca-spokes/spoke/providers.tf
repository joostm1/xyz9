terraform {
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
    external = {
      source = "hashicorp/external"
    }
    azuredevops = {
      source = "microsoft/azuredevops"
    }
    cloudflare = {
      source = "cloudflare/cloudflare"
    }
  }
}
