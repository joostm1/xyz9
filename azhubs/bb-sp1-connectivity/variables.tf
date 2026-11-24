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
  org_folder = "../../catalog"
  org        = jsondecode(file("${local.org_folder}/org.json"))
  project    = jsondecode(file("${local.org_folder}/projects/${var.project_name}.json"))
  config     = data.terraform_remote_state.ba_hubs.outputs.config
  # vault is created by am-foundation
  project_view = merge(local.config, data.terraform_remote_state.am_foundation.outputs.config.roots["am-foundation"])
  # office sites are owned by the datacenter project seed
  offices = try(local.project.offices, {})
  hub_dns_ipv4 = [
    for loc in sort(keys(local.config.roots["ba-hubs"].hubs)) :
    local.config.roots["ba-hubs"].hubs[loc].nva.addresses.private.ipv4
  ]
  hub_dns_ipv6 = [
    for loc in sort(keys(local.config.roots["ba-hubs"].hubs)) :
    local.config.roots["ba-hubs"].hubs[loc].nva.addresses.private.ipv6
  ]
}
