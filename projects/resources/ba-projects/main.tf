# resources/ba-projects/main.tf -- resources for projects, created with the projects-owner identity

# Root-module handover from predecessor
data "terraform_remote_state" "config" {
  backend = "azurerm"
  config = {
    resource_group_name  = var.resource_group_name
    storage_account_name = var.storage_account_name
    container_name       = var.project_name
    key                  = "aa-self.tfstate"
    subscription_id      = split("/", var.corp_vault_id)[2]
    tenant_id            = var.tenant_id
    use_azuread_auth     = true
  }
}
# p12 credential for azure(rm|ad|devops) provider auth via az cli
data "azurerm_key_vault_secret" "config_owner_p12" {
  name         = local.config.roots["aa-self"].secret_names.secrets.owner_p12
  key_vault_id = var.corp_vault_id
  provider     = azurerm.corp
}
data "azurerm_key_vault_certificate_data" "project_ca" {
  name         = local.config.roots["aa-self"].secret_names.certs.project_ca
  key_vault_id = var.corp_vault_id
}
# Iterate over `org/projects/*.json` files, creating resources for each project
module "project_resources" {
  source   = "./project_resources"
  for_each = local.projects
  corp = {
    storage_id = var.corp_storage_id
    vault_id   = var.corp_vault_id
  }
  org                      = local.org
  contributor_project_name = var.project_name
  project = {
    name   = each.key
    config = each.value
    # Replace a permission when this seed is in projectsOwnerGraphPermissionReplace; else keep the default.
    graph_permissions = toset([
      for p in local.projectsOwnerGraphPermissions :
      lookup(try(local.projectsOwnerGraphPermissionReplace[each.key], {}), p, p)
    ])
    ca = data.azurerm_key_vault_certificate_data.project_ca
  }
  projects_config            = local.config
  aa_self_config             = local.config.roots["aa-self"]
  existing_devops_project_id = lookup(local.existing_devops_project_ids, each.key, null)
  # own ADO project, or this identity administers another project's ADO project
  needs_devops_entitlement = (
    contains(local.devops_owner_projects, each.key)
    || (can(each.value.devops) && try(each.value.devops.owner, each.key) == each.key)
  )
  providers = { azurerm.iac = azurerm.iac }
}
# devops.owner is applied before it becomes Project Administrator
resource "azuredevops_group_membership" "devops_owner_admin" {
  for_each = {
    for name, project in local.projects : name => project
    if can(project.devops.owner) && project.devops.owner != name
  }
  group = module.project_resources[each.key].project_administrators_descriptor
  members = [
    module.project_resources[each.value.devops.owner].devops_entitlement
  ]
  mode = "add"
}
moved {
  from = module.project_resources["datacenter"].azuredevops_group_membership.project_owner_admin[0]
  to   = azuredevops_group_membership.devops_owner_admin["datacenter"]
}
# adopt ADO projects that already exist; the module creates names that are missing
data "azuredevops_projects" "existing" {
  state = "wellFormed"
}
import {
  for_each = local.existing_devops_project_ids
  to       = module.project_resources[each.key].azuredevops_project.project[0]
  id       = each.value
}
