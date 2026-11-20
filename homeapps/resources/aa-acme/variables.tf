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
variable "subscription_id" {
  type = string
}
locals {
  org_folder = "../../org"
  org        = jsondecode(file("${local.org_folder}/org.json"))
  project    = jsondecode(file("${local.org_folder}/projects/homeapps.json"))
  docker     = local.project.applications.docker
  config     = jsondecode(data.azurerm_key_vault_secret.config_init.value)
  # ha, mx1, unifi, vault. egx stays with offices DNS.
  app_hosts = toset(["ha", "mx1", "unifi", "vault"])
  opi_ssh = {
    host     = "${local.docker.host.dns_name}.${local.org.about.dns_domain}"
    user     = data.azurerm_key_vault_secret.sp1_secrets["nvaAdminUserName"].value
    password = data.azurerm_key_vault_secret.sp1_secrets["adminPK"].value
  }
}
