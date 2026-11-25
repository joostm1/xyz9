output "provisioner_user" {
  value = snowflake_service_user.provisioner.name
}
output "scim_user" {
  value = snowflake_service_user.scim.name
}
output "scim_role" {
  value = snowflake_account_role.scim_provisioner.name
}
output "scim_token" {
  value     = snowflake_user_programmatic_access_token.scim.token
  sensitive = true
}
