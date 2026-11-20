# Create account network policies (`ALLOW_ALL`, `DBT_CLOUD`) before the SCIM PAT
resource "snowflake_network_policy" "platform" {
  for_each        = local.config.snowflake.platform.network_policies
  name            = each.value.name
  allowed_ip_list = each.value.allowed_ip_list
  comment         = each.value.comment
  provider        = snowflake.initial
}
# SECURITYADMIN owns the policies so as-sflz can DESCRIBE `ALLOW_ALL` on the SCIM integration
resource "snowflake_grant_ownership" "platform_network_policy_securityadmin" {
  for_each            = snowflake_network_policy.platform
  account_role_name   = "SECURITYADMIN"
  outbound_privileges = "COPY"
  on {
    object_type = "NETWORK POLICY"
    object_name = each.value.name
  }
  provider = snowflake.initial
}
