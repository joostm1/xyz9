variable "corp_storage_id" {
  type = string
}
variable "corp_vault_id" {
  type = string
}
variable "org_name" {
  type = string
}
variable "project_name" {
  type = string
}
variable "state_key" {
  type = string
}
variable "subscription_id" {
  type = string
}
variable "tenant_id" {
  type = string
}
locals {
  config_checkout            = "../../org"
  org                        = jsondecode(file("${local.config_checkout}/org.json"))
  project                    = jsondecode(file("${local.config_checkout}/projects/${var.project_name}.json"))
  config                     = local.project # first root: seed merge chain from org project JSON
  projects_subscription_name = "xyz9-projects1"
  subscriptions_map = {
    for obj in data.azurerm_subscriptions.available.subscriptions : obj.display_name => obj if obj.state == "Enabled"
  }
  projectsOwnerGraphPermissions = [
    "Group.ReadWrite.All",
    "Group.Create",
    "Application.ReadWrite.OwnedBy",
    "User.Read.All",
    "AppRoleAssignment.ReadWrite.All",
    "Application.Read.All"
  ]
}
