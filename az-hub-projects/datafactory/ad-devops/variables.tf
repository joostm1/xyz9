# module inputs; same-project config from as-sflz remote_state
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
  org     = jsondecode(file("../../../../aa-catalog/catalog/org.json"))
  project = jsondecode(file("../../../../aa-catalog/catalog/projects/${var.project_name}.json"))
  # our predecessor
  config   = data.terraform_remote_state.as_sflz.outputs.config
  datasets = local.config.scopes.datasets
}
