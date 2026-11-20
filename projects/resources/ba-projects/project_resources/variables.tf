variable "corp" {
  type = object({
    storage_id = string
    vault_id   = string
  })
}
variable "contributor_project_name" {
  type        = string
  description = "Project that writes this config handoff under projects[contributor_project_name]"
}
variable "project" {
  type = object({
    name              = string
    config            = any
    graph_permissions = set(string)
    ca                = any
  })
}
variable "projects_config" {
  type = any
}
variable "org" {
  type = any
}
variable "aa_self_config" {
  type        = any
  description = "aa-self config"
}
variable "existing_devops_project_id" {
  type        = string
  description = "Azure DevOps project id when the project already exists"
  nullable    = true
  default     = null
}
variable "needs_devops_entitlement" {
  type        = bool
  description = "Create an Azure DevOps user for this project's owner principal"
  default     = false
}
locals {
  has_devops               = can(var.project.config.devops)
  external_devops_owner    = local.has_devops && can(var.project.config.devops.owner) && var.project.config.devops.owner != var.project.name
  projects_subscription    = var.aa_self_config.azurerm.project.shared_subscription
  projects_subscription_id = "/subscriptions/${local.projects_subscription.id}"
}
