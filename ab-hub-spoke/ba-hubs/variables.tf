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
variable "cloudflare_api_token" {
  type      = string
  sensitive = true
  default   = ""
}
locals {
  org_folder = "../../aa-catalog/catalog"
  org        = jsondecode(file("${local.org_folder}/org.json"))
  project    = jsondecode(file("${local.org_folder}/projects/${var.project_name}.json"))
  config     = data.terraform_remote_state.aa_config.outputs.config
  # lift aa-config contributions for hub paths (project.vault, project.rg, project.groups)
  project_view = merge(local.config, try(local.config.roots["aa-config"], {}))
  # office sites are owned by the datacenter project seed
  offices = try(local.project.offices, {})
}
