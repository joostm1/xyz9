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
  }
}
