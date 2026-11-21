# same-project handoff: full living object with this root under roots[state_key]
output "config" {
  value = merge(local.config, {
    roots = merge(try(local.config.roots, {}), {
      (var.state_key) = {
        org_name     = local.org.suppliers.msft.devops.org_name
        project_id   = azuredevops_project.this.id
        project_name = azuredevops_project.this.name
        adf_repos = {
          for dataset_key, repo in azuredevops_git_repository.adf : dataset_key => {
            id   = repo.id
            name = repo.name
            url  = repo.remote_url
          }
        }
        shared_repo = {
          id   = azuredevops_git_repository.shared.id
          name = azuredevops_git_repository.shared.name
          url  = azuredevops_git_repository.shared.remote_url
        }
        platform_adf_repo = {
          id   = azuredevops_git_repository.platform_adf.id
          name = azuredevops_git_repository.platform_adf.name
          url  = azuredevops_git_repository.platform_adf.remote_url
        }
      }
    })
  })
  sensitive = true
}
