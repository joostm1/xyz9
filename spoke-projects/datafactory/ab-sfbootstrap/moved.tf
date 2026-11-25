moved {
  from = tls_private_key.snowflake_provisioner
  to   = tls_private_key.snowflake_provisioner["az1"]
}
moved {
  from = snowflake_service_user.provisioner
  to   = module.snowflake_account_az1.snowflake_service_user.provisioner
}
moved {
  from = snowflake_grant_account_role.provisioner_admin_roles
  to   = module.snowflake_account_az1.snowflake_grant_account_role.provisioner_admin_roles
}
moved {
  from = snowflake_grant_privileges_to_account_role.admin_compute_warehouse_usage
  to   = module.snowflake_account_az1.snowflake_grant_privileges_to_account_role.admin_compute_warehouse_usage
}
moved {
  from = snowflake_account_parameter.enable_internal_stages_privatelink
  to   = module.snowflake_account_az1.snowflake_account_parameter.enable_internal_stages_privatelink[0]
}
moved {
  from = snowflake_network_policy.platform
  to   = module.snowflake_account_az1.snowflake_network_policy.platform
}
moved {
  from = snowflake_grant_ownership.platform_network_policy_securityadmin
  to   = module.snowflake_account_az1.snowflake_grant_ownership.platform_network_policy_securityadmin
}
moved {
  from = snowflake_account_role.scim_provisioner
  to   = module.snowflake_account_az1.snowflake_account_role.scim_provisioner
}
moved {
  from = snowflake_grant_privileges_to_account_role.scim_provisioner_account_grants
  to   = module.snowflake_account_az1.snowflake_grant_privileges_to_account_role.scim_provisioner_account_grants
}
moved {
  from = snowflake_grant_account_role.scim_provisioner_accountadmin_grant
  to   = module.snowflake_account_az1.snowflake_grant_account_role.scim_provisioner_accountadmin_grant
}
moved {
  from = snowflake_service_user.scim
  to   = module.snowflake_account_az1.snowflake_service_user.scim
}
moved {
  from = snowflake_grant_account_role.scim_service_user_role_grant
  to   = module.snowflake_account_az1.snowflake_grant_account_role.scim_service_user_role_grant
}
moved {
  from = snowflake_grant_ownership.scim_user_securityadmin
  to   = module.snowflake_account_az1.snowflake_grant_ownership.scim_user_securityadmin
}
moved {
  from = time_rotating.scim_pat
  to   = module.snowflake_account_az1.time_rotating.scim_pat
}
moved {
  from = snowflake_user_programmatic_access_token.scim
  to   = module.snowflake_account_az1.snowflake_user_programmatic_access_token.scim
}
moved {
  from = azurerm_key_vault_secret.scim_pat
  to   = azurerm_key_vault_secret.snowflake_provisioner["az1-scim-pat"]
}
moved {
  from = azurerm_key_vault_secret.snowflake_provisioner["snowflake-account-identifier"]
  to   = azurerm_key_vault_secret.snowflake_provisioner["az1-account-identifier"]
}
moved {
  from = azurerm_key_vault_secret.snowflake_provisioner["snowflake-account-identifier-privatelink"]
  to   = azurerm_key_vault_secret.snowflake_provisioner["az1-account-identifier-privatelink"]
}
moved {
  from = azurerm_key_vault_secret.snowflake_provisioner["snowflake-provisioner-private-key"]
  to   = azurerm_key_vault_secret.snowflake_provisioner["az1-provisioner-private-key"]
}
moved {
  from = azurerm_key_vault_secret.snowflake_provisioner["snowflake-provisioner-public-key"]
  to   = azurerm_key_vault_secret.snowflake_provisioner["az1-provisioner-public-key"]
}
