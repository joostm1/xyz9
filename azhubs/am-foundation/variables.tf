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
  config        = data.terraform_remote_state.aa_foundation.outputs.config
  aa_foundation = local.config.roots["aa-foundation"]
  scope_role_groups = {
    for group_key, group in module.scope_roles.by_key : group_key => {
      key          = group.key
      path         = join(".", group.path)
      scope_key    = reverse(group.path)[0]
      role         = group.value
      display_name = "sg-${var.project_name}-${group.key}"
      description  = "Functional group for ${group.value} role in ${join(".", group.path)} scope in project ${var.project_name}"
    }
  }
  entra_scope_role_groups = {
    for group_key, group in azuread_group.function_scope_role_groups : group_key => {
      display_name = group.display_name
      object_id    = group.object_id
    }
  }
}
