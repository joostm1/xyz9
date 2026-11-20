# ADO project bootstrapped by `projects`; this root owns it after import
resource "azuredevops_project" "this" {
  name               = local.project.devops.project.name
  description        = local.project.description
  visibility         = "private"
  version_control    = "Git"
  work_item_template = "Agile"
}
