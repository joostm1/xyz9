variable "corp_storage_id" {
  type = string
}
variable "corp_vault_id" {
  type = string
}
variable "project_name" {
  type = string
}
variable "resource_group_name" {
  type = string
}
variable "state_key" {
  type = string
}
variable "storage_account_name" {
  type = string
}
variable "tenant_id" {
  type = string
}
variable "org_name" {
  type = string
}
locals {
  config_checkout = "../../org"
  org             = jsondecode(file("${local.config_checkout}/org.json"))
  project         = jsondecode(file("${local.config_checkout}/projects/${var.project_name}.json"))
  # alphabetically ordered root modules under resources/ (xx-name)
  resource_modules = sort([
    for provider_file in fileset("${path.module}/..", "*/providers.tf") : dirname(provider_file)
    if can(regex("^[a-z][a-z]-", dirname(provider_file)))
  ])
  config           = data.terraform_remote_state.config.outputs.config
  projects_exclude = [var.project_name]
  projects = {
    for project_file in fileset("${local.config_checkout}/projects", "*.json") :
    trimsuffix(project_file, ".json") => jsondecode(file("${local.config_checkout}/projects/${project_file}"))
    if !contains(local.projects_exclude, trimsuffix(project_file, ".json"))
  }
  projectsOwnerGraphPermissions = [
    "Group.Read.All",
    "Group.Create",
    "Application.ReadWrite.OwnedBy",
    "User.Read.All",
    "Application.Read.All"
  ]
  # live ADO names to adopt: desired name, plus current_name while a rename is still pending
  devops_adopt_names = {
    for name, project in local.projects : name => compact([
      try(project.devops.project.name, null),
      try(project.devops.project.current_name, null),
    ])
    if can(project.devops.project.name)
  }
  # catalog projects that administer another project's ADO project; they apply first
  devops_owner_projects = distinct([
    for name, project in local.projects : project.devops.owner
    if can(project.devops.owner) && project.devops.owner != name
  ])
  # ADO project ids already in xyz9ops, keyed by catalog project name
  existing_devops_project_ids = {
    for name, wanted in local.devops_adopt_names : name => one([
      for found in data.azuredevops_projects.existing.projects : found.project_id
      if contains(wanted, found.name)
    ])
    if length([
      for found in data.azuredevops_projects.existing.projects : found
      if contains(wanted, found.name)
    ]) > 0
  }
  # datacenter: Application.ReadWrite.All instead of OwnedBy
  projectsOwnerGraphPermissionReplace = {
    datacenter = {
      "Application.ReadWrite.OwnedBy" = "Application.ReadWrite.All"
    }
  }
}
