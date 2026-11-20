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
variable "subscription_id" {
  type = string
}
variable "storage_account_name" {
  type = string
}
variable "resource_group_name" {
  type = string
}
locals {
  org_folder = "../../org"
  org        = jsondecode(file("${local.org_folder}/org.json"))
  project    = jsondecode(file("${local.org_folder}/projects/${var.project_name}.json"))
  config     = data.terraform_remote_state.aa_config.outputs.config
  # lift aa-config contributions for hub paths (project.vault, project.rg, project.groups)
  project_view = merge(local.config, try(local.config.roots["aa-config"], {}))
  # office sites are owned by the offices project seed
  offices = jsondecode(file("${local.org_folder}/projects/offices.json")).offices
}
