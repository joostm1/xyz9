output "factory_id" {
  value = azurerm_data_factory.this.id
}
output "factory_name" {
  value = azurerm_data_factory.this.name
}
output "principal_id" {
  value = azurerm_data_factory.this.identity[0].principal_id
}
output "bootstrap" {
  value = azuredevops_git_repository_file.bootstrap
}
output "files" {
  value = azuredevops_git_repository_file.this
}
output "deploy" {
  value = {
    id                      = azurerm_user_assigned_identity.adf_deploy.id
    client_id               = azurerm_user_assigned_identity.adf_deploy.client_id
    principal_id            = azurerm_user_assigned_identity.adf_deploy.principal_id
    service_connection_name = azuredevops_serviceendpoint_azurerm.adf_deploy.service_endpoint_name
  }
}
