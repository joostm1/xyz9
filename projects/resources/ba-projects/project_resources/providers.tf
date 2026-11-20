terraform {
  required_providers {
    azurerm = {
      source                = "hashicorp/azurerm"
      configuration_aliases = [azurerm.iac]
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
