# per-dataset ADF git repos in this root's ADO project
# Clean init leaves no branches; ba-azure/dataset seeds develop via publish_config.json
resource "azuredevops_git_repository" "adf" {
  for_each       = local.datasets
  project_id     = azuredevops_project.this.id
  name           = "${each.key}.adf"
  default_branch = "refs/heads/develop"
  initialization {
    init_type = "Clean"
  }
}
# platform templates; ba-azure seeds main (Clean leaves no branches)
resource "azuredevops_git_repository" "shared" {
  project_id     = azuredevops_project.this.id
  name           = "shared"
  default_branch = "refs/heads/main"
  initialization {
    init_type = "Clean"
  }
}
# platform SHIR host ADF; ba-azure seeds develop via publish_config.json
resource "azuredevops_git_repository" "platform_adf" {
  project_id     = azuredevops_project.this.id
  name           = "${local.project.name}.adf"
  default_branch = "refs/heads/develop"
  initialization {
    init_type = "Clean"
  }
}
# ADO: "There must always be at least one repository per Team Project."
# Create-only. Destroy drops this object and leaves the git repo; deleting the project removes it.
resource "terraform_data" "destroy_holder" {
  input = azuredevops_project.this.id
  provisioner "local-exec" {
    command     = "scripts/create_destroy_holder_repo.py"
    working_dir = path.module
    interpreter = ["python3"]
    environment = {
      org_url    = "https://dev.azure.com/${local.org.suppliers.msft.devops.org_name}"
      project_id = azuredevops_project.this.id
      repo_name  = "destroy-holder"
    }
  }
}
locals {
  # keys from catalog names, not resource attributes, so git_acl for_each stays known
  git_repos = merge(
    { for k in keys(local.datasets) : "${k}.adf" => { id = azuredevops_git_repository.adf[k].id, kind = "adf", dataset_key = k } },
    { shared = { id = azuredevops_git_repository.shared.id, kind = "shared", dataset_key = null } },
    { "${local.project.name}.adf" = { id = azuredevops_git_repository.platform_adf.id, kind = "platform", dataset_key = null } }
  )
}
