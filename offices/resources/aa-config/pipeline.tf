# Repo origin is xyz9ops/xyz9it/offices. Definition 31 already exists as xyz9sp1-apply.
import {
  to = azuredevops_build_definition.apply
  id = "xyz9it/31"
}
data "azuredevops_project" "xyz9it" {
  name = "xyz9it"
}
data "azuredevops_git_repository" "this" {
  project_id = data.azuredevops_project.xyz9it.id
  name       = var.project_name
}
resource "azuredevops_build_definition" "apply" {
  project_id      = data.azuredevops_project.xyz9it.id
  name            = "xyz9sp1-apply"
  agent_pool_name = "Azure Pipelines" # Microsoft-hosted; YAML selects the image
  ci_trigger {
    use_yaml = true # trigger and the monthly cron stay in azure-pipelines.yml
  }
  repository {
    repo_type           = "TfsGit"
    repo_id             = data.azuredevops_git_repository.this.id
    branch_name         = "refs/heads/develop"
    yml_path            = "azure-pipelines.yml"
    report_build_status = false # current definition; provider default is true
  }
  # ~/.tfbackend.hcl. container_name and key stay per root, from the Makefile.
  variable {
    name           = "resource_group_name"
    value          = var.resource_group_name
    allow_override = false
  }
  variable {
    name           = "storage_account_name"
    value          = var.storage_account_name
    allow_override = false
  }
  variable {
    name           = "subscription_id"
    value          = split("/", var.corp_vault_id)[2]
    allow_override = false
  }
  variable {
    name           = "tenant_id"
    value          = var.tenant_id
    allow_override = false
  }
  # Not a backend key. make still passes -var-file=$HOME/.tfvars, which needs this.
  variable {
    name           = "corp_vault_id"
    value          = var.corp_vault_id
    allow_override = false
  }
}
