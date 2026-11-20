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
  org_folder = "../../org"
  org        = jsondecode(file("${local.org_folder}/org.json"))
  project = jsondecode(file("${local.org_folder}/projects/offices.json"))
  sp1     = local.project.offices.sp1 # this repo; project_name stays the Azure name
  config  = jsondecode(data.azurerm_key_vault_secret.config_init.value)
  # App host certificates are homeapps resources/aa-acme. egx is the router.
  sp1_hosts = toset(["egx"])

  dns_aliases = {
    egx_public_ipv4 = ["postgres"]
    opi_public_ipv6 = ["postgres", "mx1", "ha", "unifi"]
  }
}
