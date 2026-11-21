variable "org_name" {
  type = string
}
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
  org     = jsondecode(file("../../../aa-catalog/org.json"))
  project = jsondecode(file("../../../aa-catalog/projects/${var.project_name}.json"))
  # living object from corp KV; overlay seed without wiping roots/projects
  config = merge(
    nonsensitive(jsondecode(data.azurerm_key_vault_secret.project_config.value)),
    { for k, v in local.project : k => v if !contains(["roots", "projects"], k) }
  )
  project_vault_owner_principals = {
    app   = local.config.projects.projects.identity.owner.app_object_id
    group = local.config.projects.projects.identity.owner.group_object_id
  }
}
