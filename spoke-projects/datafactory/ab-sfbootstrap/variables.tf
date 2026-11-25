variable "state_key" {
  type = string
}
variable "project_name" {
  type = string
}
variable "corp_vault_id" {
  type = string
}
variable "tenant_id" {
  type = string
}
variable "storage_account_name" {
  type = string
}
variable "resource_group_name" {
  type = string
}
locals {
  org         = jsondecode(file("../../../catalog/org.json"))
  project     = jsondecode(file("../../../catalog/projects/${var.project_name}.json"))
  azhubs_seed = jsondecode(file("../../../catalog/projects/azhubs.json"))
  # kv-xyz9-azhubs holds datafactory-config and datafactory-owner-p12
  azhubs_vault_id = "/subscriptions/${local.azhubs_seed.azure.subscription_id}/resourceGroups/${local.azhubs_seed.azure.rg.name}/providers/Microsoft.KeyVault/vaults/kv-${local.org.name}-azhubs"
  # living object from kv-xyz9-azhubs; overlay seed without wiping roots/projects
  config = merge(
    nonsensitive(jsondecode(data.azurerm_key_vault_secret.project_config.value)),
    { for k, v in local.project : k => v if !contains(["roots", "projects"], k) }
  )
  project_vault_owner_principals = {
    app   = local.config.projects.azhubs.client.service_principal.object_id
    group = local.config.projects.azhubs.owner_group.object_id
  }
  # corp vault secret `snowflake-accounts`: one object per account, keyed by name
  snowflake_account_list = nonsensitive(jsondecode(data.azurerm_key_vault_secret.snowflake_accounts.value))
  snowflake_accounts = {
    for account in local.snowflake_account_list : account.name => {
      name                    = account.name
      identifier              = account.identifier
      username                = account.username
      cloud_platform          = account.cloud_platform
      private_key_secret_name = account.private_key_secret_name
      organization_name       = split("-", lower(account.identifier))[0]
      account_name            = split("-", lower(account.identifier))[1]
    }
  }
  account_secret_names = {
    for name, account in local.snowflake_accounts : name => {
      account_identifier             = "${name}-account-identifier"
      account_identifier_privatelink = "${name}-account-identifier-privatelink"
      private_key                    = "${name}-provisioner-private-key"
      public_key                     = "${name}-provisioner-public-key"
      scim_pat                       = "${name}-scim-pat"
    }
  }
}
