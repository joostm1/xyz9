# module inputs; same-project config from ab-sfbootstrap remote_state
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
  org     = jsondecode(file("../../../catalog/org.json"))
  project = jsondecode(file("../../../catalog/projects/${var.project_name}.json"))
  config  = data.terraform_remote_state.am_sfbootstrap.outputs.config
  # private DNS zones are in the same resource group as kv-xyz9-azhubs
  private_dns_rg_id  = regex("^/subscriptions/[^/]+/resourceGroups/[^/]+", local.config.projects.azhubs.vault.id)
  snowflake_accounts = local.config.snowflake.accounts
}
