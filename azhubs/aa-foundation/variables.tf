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
  org_folder = "../../catalog"
  org        = jsondecode(file("${local.org_folder}/org.json"))
  # strip $schema so it does not leak into remote state via merge → output.config
  project = {
    for k, v in jsondecode(file("${local.org_folder}/projects/${var.project_name}.json")) : k => v if k != "$schema"
  }
}
