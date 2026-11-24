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
  config     = data.terraform_remote_state.ba_hubs.outputs.config
  # rg-azhubs is created by am-foundation; azure.private_dns_zones stays on the seed in config
  project_view = merge(local.config, data.terraform_remote_state.am_foundation.outputs.config.roots["am-foundation"])
  # deployed hubs from predecessor root
  hubs = try(local.config.roots["ba-hubs"].hubs, {})
  # spoke candidates: hub_location alone filters
  catalog = {
    for f in fileset("${local.org_folder}/projects", "*.json") :
    trimsuffix(f, ".json") => jsondecode(file("${local.org_folder}/projects/${f}"))
  }
  spoke_projects = {
    for name, project in local.catalog : name => project if contains(keys(project), "hub_location")
  }
}
