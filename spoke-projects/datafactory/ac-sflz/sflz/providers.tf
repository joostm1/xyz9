terraform {
  required_providers {
    snowflake = {
      source = "snowflakedb/snowflake"
      configuration_aliases = [
        snowflake.accountadmin,
        snowflake.securityadmin,
        snowflake.sysadmin,
      ]
    }
    azurerm = {
      source = "hashicorp/azurerm"
    }
    azuread = {
      source = "hashicorp/azuread"
    }
    random = {
      source = "hashicorp/random"
    }
    time = {
      source = "hashicorp/time"
    }
    local = {
      source = "hashicorp/local"
    }
  }
}
