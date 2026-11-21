moved {
  from = azurerm_data_factory.this
  to   = module.adf.azurerm_data_factory.this
}
moved {
  from = azurerm_role_assignment.adf_ext_stage_blob
  to   = module.adf.azurerm_role_assignment.ext_stage_blob
}
moved {
  from = azurerm_role_assignment.adf_account_identifier_privatelink
  to   = module.adf.azurerm_role_assignment.account_identifier_privatelink
}
moved {
  from = azurerm_role_assignment.adf_dataset_vault
  to   = module.adf.azurerm_role_assignment.dataset_vault[0]
}
moved {
  from = azurerm_role_assignment.adf_shir_contributor
  to   = module.adf.azurerm_role_assignment.shir_contributor[0]
}
moved {
  from = azurerm_user_assigned_identity.adf_deploy
  to   = module.adf.azurerm_user_assigned_identity.adf_deploy
}
moved {
  from = azurerm_role_assignment.adf_deploy
  to   = module.adf.azurerm_role_assignment.adf_deploy
}
moved {
  from = azurerm_federated_identity_credential.adf_deploy
  to   = module.adf.azurerm_federated_identity_credential.adf_deploy
}
moved {
  from = azuredevops_serviceendpoint_azurerm.adf_deploy
  to   = module.adf.azuredevops_serviceendpoint_azurerm.adf_deploy
}
moved {
  from = azuredevops_build_definition.adf_publish
  to   = module.adf.azuredevops_build_definition.adf_publish
}
moved {
  from = azuredevops_pipeline_authorization.adf_deploy
  to   = module.adf.azuredevops_pipeline_authorization.adf_deploy
}
moved {
  from = azuredevops_pipeline_authorization.shared_repo
  to   = module.adf.azuredevops_pipeline_authorization.shared_repo
}
moved {
  from = module.adf_git.azuredevops_git_repository_file.bootstrap
  to   = module.adf.azuredevops_git_repository_file.bootstrap
}
moved {
  from = module.adf_git.azuredevops_git_repository_file.this
  to   = module.adf.azuredevops_git_repository_file.this
}
