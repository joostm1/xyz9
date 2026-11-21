# platform collaboration factory + publish pipeline; SHIR host stays in platform_adf.tf
# deploy UAMI is Contributor on the DC spoke RG (factory lives there with SHIR VM and util)
module "platform_adf" {
  source = "../../modules/adf"
  kind   = "platform"
  factory = {
    name                = local.resource_names.az.shir_host_adf
    location            = local.config.projects.datacenter.spoke.rg.location
    resource_group_name = local.config.projects.datacenter.spoke.rg.name
  }
  devops = {
    org_name               = local.config.roots["au-devops"].org_name
    project_id             = local.config.roots["au-devops"].project_id
    project_name           = local.config.roots["au-devops"].project_name
    repository_id          = local.config.roots["au-devops"].platform_adf_repo.id
    repository_name        = local.config.roots["au-devops"].platform_adf_repo.name
    shared_repository_id   = local.config.roots["au-devops"].shared_repo.id
    shared_repository_name = local.config.roots["au-devops"].shared_repo.name
    tenant_id              = var.tenant_id
  }
  deploy = {
    identity_name     = local.resource_names.az.adf_deploy_platform
    tenant_id         = local.config.projects.projects.entra.tenant_id
    resource_group_id = local.config.projects.datacenter.spoke.rg.id
    subscription = {
      id   = local.config.projects.projects.azurerm.subscription.id
      name = local.config.projects.projects.azurerm.subscription.name
    }
  }
  shir = {
    name        = local.resource_names.az.shir_ir
    description = "Shared self-hosted integration runtime for ${local.project.name} dataset factories"
  }
  connections = {
    project_name                               = local.project.name
    project_vault_uri                          = local.config.roots["am-sfbootstrap"].project_vault_uri
    project_vault_id                           = local.config.roots["am-sfbootstrap"].project_vault_id
    account_identifier_privatelink_secret_name = local.config.roots["am-sfbootstrap"].provisioner.secret_names.account_identifier_privatelink
    account_identifier_privatelink_secret_id   = local.config.roots["am-sfbootstrap"].provisioner.secret_resource_ids.account_identifier_privatelink
    adf_key_secret_name                        = azurerm_key_vault_secret.platform_adf_key.name
    snowflake_database                         = local.config.roots["as-sflz"].platform.database
    snowflake_role                             = snowflake_service_user.platform_adf.default_role
    snowflake_user                             = snowflake_service_user.platform_adf.name
    snowflake_warehouse                        = snowflake_service_user.platform_adf.default_warehouse
    ext_stage_id                               = local.config.roots["as-sflz"].resource_ids.ext_stage
    ext_stage_account_name                     = local.config.roots["as-sflz"].resource_names.az.ext_stage
  }
  depends_on = [azuredevops_git_repository_file.adf_publish_template]
}
