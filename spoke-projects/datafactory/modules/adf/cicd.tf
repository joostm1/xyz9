locals {
  deploy_key = var.kind == "dataset" ? var.dataset.dataset_key : "platform"
}
resource "azurerm_user_assigned_identity" "adf_deploy" {
  name                = var.deploy.identity_name
  location            = var.factory.location
  resource_group_name = var.factory.resource_group_name
}
# RG-scoped ARM deployments plus trigger start/stop; factory MI still reads Key Vault at runtime
resource "azurerm_role_assignment" "adf_deploy" {
  scope                = var.deploy.resource_group_id
  role_definition_name = "Contributor"
  principal_id         = azurerm_user_assigned_identity.adf_deploy.principal_id
  principal_type       = "ServicePrincipal"
}
resource "azuredevops_serviceendpoint_azurerm" "adf_deploy" {
  project_id                             = var.devops.project_id
  service_endpoint_name                  = "adf-deploy-${local.deploy_key}"
  description                            = var.kind == "dataset" ? "WIF ARM deploy for dataset ${var.dataset.dataset_key}" : "WIF ARM deploy for platform"
  service_endpoint_authentication_scheme = "WorkloadIdentityFederation"
  credentials {
    serviceprincipalid = azurerm_user_assigned_identity.adf_deploy.client_id
  }
  azurerm_spn_tenantid      = var.deploy.tenant_id
  azurerm_subscription_id   = var.deploy.subscription.id
  azurerm_subscription_name = var.deploy.subscription.name
  features {
    validate = false # federated credential is created after this endpoint exists
  }
}
resource "azurerm_federated_identity_credential" "adf_deploy" {
  name                      = "ado-adf-deploy-${local.deploy_key}"
  user_assigned_identity_id = azurerm_user_assigned_identity.adf_deploy.id
  audience                  = ["api://AzureADTokenExchange"]
  issuer                    = azuredevops_serviceendpoint_azurerm.adf_deploy.workload_identity_federation_issuer
  subject                   = azuredevops_serviceendpoint_azurerm.adf_deploy.workload_identity_federation_subject
}
resource "azuredevops_build_definition" "adf_publish" {
  project_id      = var.devops.project_id
  name            = "${var.devops.repository_name} publish"
  agent_pool_name = "Azure Pipelines"
  ci_trigger {
    use_yaml = true
  }
  repository {
    repo_type   = "TfsGit"
    repo_id     = var.devops.repository_id
    branch_name = "refs/heads/develop"
    yml_path    = "azure-pipelines.yml"
  }
  variable {
    name  = "factoryId"
    value = azurerm_data_factory.this.id
  }
  variable {
    name  = "factoryName"
    value = azurerm_data_factory.this.name
  }
  variable {
    name  = "resourceGroupName"
    value = var.factory.resource_group_name
  }
  variable {
    name  = "location"
    value = var.factory.location
  }
  variable {
    name  = "azureRmServiceConnection"
    value = azuredevops_serviceendpoint_azurerm.adf_deploy.service_endpoint_name
  }
  features {
    skip_first_run = true
  }
  depends_on = [azuredevops_git_repository_file.this]
}
resource "azuredevops_pipeline_authorization" "adf_deploy" {
  project_id  = var.devops.project_id
  resource_id = azuredevops_serviceendpoint_azurerm.adf_deploy.id
  type        = "endpoint"
  pipeline_id = azuredevops_build_definition.adf_publish.id
}
resource "azuredevops_pipeline_authorization" "shared_repo" {
  project_id  = var.devops.project_id
  resource_id = var.devops.shared_repository_id #  Error: creating authorized resource: Resource id exceeds maximum length of 100.
  type        = "repository"
  pipeline_id = azuredevops_build_definition.adf_publish.id
}
