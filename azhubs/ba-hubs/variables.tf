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
variable "cloudflare_api_token" {
  type      = string
  sensitive = true
  default   = ""
}
locals {
  org_folder = "../../catalog"
  org        = jsondecode(file("${local.org_folder}/org.json"))
  project    = jsondecode(file("${local.org_folder}/projects/${var.project_name}.json"))
  config = data.terraform_remote_state.aa_foundation.outputs.config
  # rg, vault, and groups are created by am-foundation
  project_view = merge(local.config, data.terraform_remote_state.am_foundation.outputs.config.roots["am-foundation"])
  # office sites are owned by the datacenter project seed
  offices = try(local.project.offices, {})
}
