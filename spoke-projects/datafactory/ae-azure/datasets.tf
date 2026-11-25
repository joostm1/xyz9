# per dataset resouces
module "datasets" {
  for_each = local.datasets
  source   = "./dataset"
  providers = {
    snowflake.useradmin     = snowflake.useradmin
    snowflake.securityadmin = snowflake.securityadmin
  }
  dataset_key  = each.key
  project_name = local.project.name
  location     = local.config.projects.azhubs.spoke.rg.location
  names = {
    rg         = local.resource_names.az.adf_rg[each.key]
    adf        = local.resource_names.az.adf[each.key]
    vault      = local.resource_names.az.dataset_vault[each.key]
    adf_pe     = local.resource_names.az.adf_pe[each.key]
    adf_deploy = local.resource_names.az.adf_deploy[each.key]
    shir_ir    = local.resource_names.az.shir_ir
  }
  tenant_id             = var.tenant_id
  owner_app_object_id   = local.config.projects.azhubs.client.service_principal.object_id
  owner_group_object_id = local.config.projects.azhubs.owner_group.object_id
  subscription = {
    id   = local.config.projects.azhubs.subscription.id
    name = local.config.projects.azhubs.subscription.name
  }
  subnet_id = local.config.projects.azhubs.spoke.vnet.vn1.subnets.sn1.id
  role_admin_object_ids = {
    for k, v in local.config.roots["ac-sflz"].roles.datasets : k => v.object_id
    if v.dataset_key == each.key
  }
  shir_ir_id = azurerm_data_factory_integration_runtime_self_hosted.shir.id
  devops = {
    org_name               = local.config.roots["ad-devops"].org_name
    project_id             = local.config.roots["ad-devops"].project_id
    project_name           = local.config.roots["ad-devops"].project_name
    repository_id          = local.config.roots["ad-devops"].adf_repos[each.key].id
    repository_name        = local.config.roots["ad-devops"].adf_repos[each.key].name
    shared_repository_id   = local.config.roots["ad-devops"].shared_repo.id
    shared_repository_name = local.config.roots["ad-devops"].shared_repo.name
    tenant_id              = var.tenant_id
  }
  project_vault_uri                          = local.config.roots["ab-sfbootstrap"].project_vault_uri
  account_identifier_privatelink_secret_name = local.azure_snowflake.provisioner.secret_names.account_identifier_privatelink
  account_identifier_privatelink_secret_id   = local.azure_snowflake.provisioner.secret_resource_ids.account_identifier_privatelink
  ext_stage_id                               = local.azure_sflz.resource_ids.ext_stage
  ext_stage_account_name                     = local.azure_sflz.resource_names.az.ext_stage
  depends_on                                 = [azapi_resource_action.shir_install, azuredevops_git_repository_file.adf_publish_template]
}
