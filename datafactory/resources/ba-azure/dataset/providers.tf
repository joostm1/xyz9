terraform {
  required_providers {
    azurerm = {
      source = "hashicorp/azurerm"
    }
    azuredevops = {
      source = "microsoft/azuredevops"
    }
    tls = {
      source = "hashicorp/tls"
    }
    snowflake = {
      source                = "snowflakedb/snowflake"
      configuration_aliases = [snowflake.useradmin, snowflake.securityadmin]
    }
  }
}
