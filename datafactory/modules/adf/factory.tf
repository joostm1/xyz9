# collaboration factory; vsts needs develop (git bootstrap) before Studio can bind
resource "azurerm_data_factory" "this" {
  name                   = var.factory.name
  location               = var.factory.location
  resource_group_name    = var.factory.resource_group_name
  public_network_enabled = true
  identity {
    type = "SystemAssigned"
  }
  dynamic "global_parameter" {
    for_each = var.factory.global_parameters
    content {
      name  = global_parameter.key
      type  = global_parameter.value.type
      value = global_parameter.value.value
    }
  }
  vsts_configuration {
    account_name       = var.devops.org_name
    branch_name        = "develop"
    project_name       = var.devops.project_name
    repository_name    = var.devops.repository_name
    root_folder        = "/"
    tenant_id          = var.devops.tenant_id
    publishing_enabled = false
  }
  depends_on = [azuredevops_git_repository_file.bootstrap]
}
resource "azurerm_role_assignment" "ext_stage_blob" {
  scope                = var.connections.ext_stage_id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = azurerm_data_factory.this.identity[0].principal_id
  principal_type       = "ServicePrincipal"
}
resource "azurerm_role_assignment" "account_identifier_privatelink" {
  scope                = var.connections.account_identifier_privatelink_secret_id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = azurerm_data_factory.this.identity[0].principal_id
  principal_type       = "ServicePrincipal"
}
resource "azurerm_role_assignment" "project_vault" {
  count                = var.kind == "platform" ? 1 : 0
  scope                = var.connections.project_vault_id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = azurerm_data_factory.this.identity[0].principal_id
  principal_type       = "ServicePrincipal"
}
resource "azurerm_role_assignment" "dataset_vault" {
  count                = var.kind == "dataset" ? 1 : 0
  scope                = var.dataset.dataset_vault_id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = azurerm_data_factory.this.identity[0].principal_id
  principal_type       = "ServicePrincipal"
}
# factory MI needs Contributor on the shared IR before the linked IR can be created
resource "azurerm_role_assignment" "shir_contributor" {
  count                = var.kind == "dataset" ? 1 : 0
  scope                = var.shir.resource_id
  role_definition_name = "Contributor"
  principal_id         = azurerm_data_factory.this.identity[0].principal_id
  principal_type       = "ServicePrincipal"
}
