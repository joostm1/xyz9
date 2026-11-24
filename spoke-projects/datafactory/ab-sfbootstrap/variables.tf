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
}
