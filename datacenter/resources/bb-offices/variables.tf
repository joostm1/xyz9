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
  config     = data.terraform_remote_state.ba_hubs.outputs.config
  # lift aa-config contributions (project.vault)
  project_view = merge(local.config, try(local.config.roots["aa-config"], {}))
  # office sites are owned by the offices project seed
  offices = jsondecode(file("${local.org_folder}/projects/offices.json")).offices
  hub_dns_ipv4 = [
    for loc in sort(keys(local.config.roots["ba-hubs"].locations)) :
    local.config.roots["ba-hubs"].locations[loc].nva.addresses.private.ipv4
  ]
  hub_dns_ipv6 = [
    for loc in sort(keys(local.config.roots["ba-hubs"].locations)) :
    local.config.roots["ba-hubs"].locations[loc].nva.addresses.private.ipv6
  ]
}
