terraform {
  required_providers {
    snowflake = {
      source                = "snowflakedb/snowflake"
      configuration_aliases = [snowflake.accountadmin]
    }
    azurerm = {
      source = "hashicorp/azurerm"
    }
    azuread = {
      source = "hashicorp/azuread"
    }
    azapi = {
      source = "Azure/azapi"
    }
    time = {
      source = "hashicorp/time"
    }
    external = {
      source = "hashicorp/external"
    }
  }
}
