moved {
  from = azurerm_data_factory.platform
  to   = module.platform_adf.azurerm_data_factory.this
}
moved {
  from = azurerm_role_assignment.platform_adf_project_vault
  to   = module.platform_adf.azurerm_role_assignment.project_vault[0]
}
moved {
  from = azurerm_role_assignment.platform_adf_account_identifier_privatelink
  to   = module.platform_adf.azurerm_role_assignment.account_identifier_privatelink
}
moved {
  from = azurerm_role_assignment.platform_adf_ext_stage_blob
  to   = module.platform_adf.azurerm_role_assignment.ext_stage_blob
}
moved {
  from = module.platform_adf_git.azuredevops_git_repository_file.bootstrap
  to   = module.platform_adf.azuredevops_git_repository_file.bootstrap
}
moved {
  from = module.platform_adf_git.azuredevops_git_repository_file.this
  to   = module.platform_adf.azuredevops_git_repository_file.this
}
