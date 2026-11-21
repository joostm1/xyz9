# Entra groups from as-sflz; platform keys are enumerator keys, dataset keys drop the dataset- prefix
# dataset-nyt-engineer + git { all = read, own.adf = contribute } + repos nyt.adf/knmi.adf/shared/datafactory.adf
# → dataset-nyt-engineer:all (project-level read), dataset-nyt-engineer:own.adf:nyt.adf (contribute)
locals {
  entra_roles = merge(local.config.roots["as-sflz"].roles.platform, local.config.roots["as-sflz"].roles.datasets)
  role_assignments = {
    for key, entry in module.project_roles.by_key : key => {
      key         = key
      dataset_key = length(entry.path) > 1 ? entry.path[1] : null
      entra       = local.entra_roles[entry.normalized_path[0] == "platform" ? key : trimprefix(key, "dataset-")]
      set         = local.project.devops.permission_sets[local.project.devops.role_permission_sets[entry.normalized_path[0]][entry.role]]
    }
  }
  git_acl_all = {
    for role_key, a in local.role_assignments : "${role_key}:all" => {
      role_key      = role_key
      repository_id = null
      permissions   = local.project.devops.git_acls[a.set.git["all"]]
    } if contains(keys(a.set.git), "all")
  }
  # own.adf → { kind = adf, join_key = nyt:adf }; platform roles have no own.* and drop out
  own_claims = {
    for row in flatten([
      for role_key, a in local.role_assignments : [
        for selector, acl_name in a.set.git : {
          role_key    = role_key
          dataset_key = a.dataset_key
          kind        = trimprefix(selector, "own.")
          join_key    = "${a.dataset_key}:${trimprefix(selector, "own.")}"
          permissions = local.project.devops.git_acls[acl_name]
        } if startswith(selector, "own.") && a.dataset_key != null
      ]
    ]) : "${row.role_key}:own.${row.kind}" => row
  }
}
# inner join own_claims to dataset repos on dataset_key:kind; repo.id stays out so for_each keys stay known
module "git_acl_own" {
  source = "../../../aa-catalog/terraform/modules/map_join"
  left   = local.own_claims
  right = {
    for name, repo in local.git_repos : name => {
      kind        = repo.kind
      dataset_key = repo.dataset_key
      join_key    = "${repo.dataset_key}:${repo.kind}"
    } if repo.dataset_key != null
  }
  left_match_attr  = "join_key"
  right_match_attr = "join_key"
  key_attrs        = ["left_key", "right_key"]
}
locals {
  git_acl_own = {
    for row in module.git_acl_own.entries : "${row.left_key}:${row.right_key}" => {
      role_key      = row.role_key
      repository_id = local.git_repos[row.right_key].id
      permissions   = row.permissions
    }
  }
  git_acl_assignments = merge(local.git_acl_all, local.git_acl_own)
}
data "azuredevops_group" "builtin" {
  for_each   = toset([for a in values(local.role_assignments) : a.set.project_group])
  project_id = azuredevops_project.this.id
  name       = each.value
}
# this identity may sign in to this organization, express is the API name for Basic
resource "azuredevops_group_entitlement" "roles" {
  for_each             = local.role_assignments
  origin               = "aad"
  origin_id            = each.value.entra.object_id
  account_license_type = "express"
}
resource "azuredevops_group_membership" "builtin" {
  for_each = data.azuredevops_group.builtin
  group    = each.value.descriptor
  mode     = "add"
  members = [
    for a in values(local.role_assignments) : azuredevops_group_entitlement.roles[a.key].descriptor
    if a.set.project_group == each.key
  ]
}
resource "azuredevops_git_permissions" "roles" {
  for_each      = local.git_acl_assignments
  project_id    = azuredevops_project.this.id
  repository_id = each.value.repository_id
  principal     = azuredevops_group_entitlement.roles[each.value.role_key].descriptor
  permissions   = each.value.permissions
  replace       = false
}
