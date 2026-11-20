# Entra SAML app + Snowflake SAML security integration for interactive login
resource "random_uuid" "project_roles" {
  for_each = module.project_roles.by_key
  keepers = {
    role_name = each.value.name
  }
}
# az rest --method get --url https://graph.microsoft.com/v1.0/applicationTemplates?\$filter=contains(displayName,'Snowflake')
data "azuread_application_template" "snowflake_entra_sso" {
  display_name = "Snowflake for Microsoft Entra ID"
}
# saml sso integration app - https://learn.microsoft.com/en-us/entra/identity/saas-apps/snowflake-tutorial
resource "azuread_application" "snowflake_entraid_sso_app" {
  display_name = "Snowflake ${lower(data.azurerm_key_vault_secret.snowflake["snowflake-account-identifier"].value)} SAML SSO"
  description  = "Snowflake ${lower(data.azurerm_key_vault_secret.snowflake["snowflake-account-identifier"].value)} SAML SSO integration application"
  template_id  = data.azuread_application_template.snowflake_entra_sso.id
  owners       = toset([local.config.projects.projects.identity.owner.user_object_id, local.config.projects.projects.identity.owner.app_object_id])
  identifier_uris = [
    "https://${lower(data.azurerm_key_vault_secret.snowflake["snowflake-account-identifier"].value)}.${local.resource_names.snowflake.service_urls.svc}"
  ]
  api {
    requested_access_token_version = 2
  }
  logo_image       = filebase64("./snowflake-logo.png")
  sign_in_audience = "AzureADMyOrg"
  feature_tags {
    custom_single_sign_on = true # required for saml
    enterprise            = true
  }
  web {
    redirect_uris = ["https://${lower(data.azurerm_key_vault_secret.snowflake["snowflake-account-identifier"].value)}.${local.resource_names.snowflake.service_urls.svc}/fed/login"]
    logout_url    = "https://${lower(data.azurerm_key_vault_secret.snowflake["snowflake-account-identifier"].value)}.${local.resource_names.snowflake.service_urls.svc}/fed/logout"
    implicit_grant {
      access_token_issuance_enabled = false
      id_token_issuance_enabled     = true
    }
  }
  dynamic "app_role" {
    for_each = module.project_roles.by_key
    iterator = role
    content {
      allowed_member_types = ["User"]
      description          = "Role for ${role.key} in the Snowflake account"
      display_name         = role.value.name
      id                   = random_uuid.project_roles[role.key].id
      value                = upper(replace(role.value.name, "-", "_"))
    }
  }
}
resource "azuread_service_principal" "snowflake_entraid_sso_principal" {
  client_id                    = azuread_application.snowflake_entraid_sso_app.client_id
  owners                       = toset([local.config.projects.projects.identity.owner.user_object_id, local.config.projects.projects.identity.owner.app_object_id])
  use_existing                 = true # adopt the principal created by snowflake_entraid_sso_app
  app_role_assignment_required = true
  feature_tags {
    custom_single_sign_on = true # required for saml
    enterprise            = true
  }
  preferred_single_sign_on_mode = "saml"
  login_url                     = "https://${lower(data.azurerm_key_vault_secret.snowflake["snowflake-account-identifier"].value)}.${local.resource_names.snowflake.service_urls.svc}" // Sign on URL on single sign on page
}
resource "time_rotating" "snowflake_entraid_sso_cert_rotation" {
  rotation_days = 365
}
resource "time_offset" "snowflake_entraid_sso_cert_end" {
  base_rfc3339 = time_rotating.snowflake_entraid_sso_cert_rotation.rfc3339
  offset_years = 2
}
resource "azuread_service_principal_token_signing_certificate" "snowflake_entraid_sso_cert" {
  service_principal_id = azuread_service_principal.snowflake_entraid_sso_principal.id
  display_name         = "CN=snowflake-entraid-sso-cert"
  end_date             = time_offset.snowflake_entraid_sso_cert_end.rfc3339
  lifecycle {
    replace_triggered_by = [
      time_rotating.snowflake_entraid_sso_cert_rotation,
    ]
  }
}
# create ad groups for each project role
resource "azuread_group" "project_roles" {
  for_each         = module.project_roles.by_key
  display_name     = "sg-${var.project_name}-${each.value.name}"
  description      = "security group for the ${each.value.name} role in the snowflake account"
  owners           = toset([local.config.projects.projects.identity.owner.user_object_id, local.config.projects.projects.identity.owner.app_object_id])
  security_enabled = true
}
# assign the groups to the app_roles in the sso integration app
resource "azuread_app_role_assignment" "snowflake_entraid_sso_app_roles" {
  for_each            = module.project_roles.by_key
  principal_object_id = azuread_group.project_roles[each.key].object_id
  app_role_id         = random_uuid.project_roles[each.key].id
  resource_object_id  = azuread_service_principal.snowflake_entraid_sso_principal.object_id
}
# securityadmin owns integrations, except scim
resource "snowflake_grant_privileges_to_account_role" "securityadmin_create_integration" {
  account_role_name = "SECURITYADMIN"
  privileges        = ["CREATE INTEGRATION"]
  on_account        = true
  provider          = snowflake.accountadmin
}
resource "snowflake_saml2_integration" "snowflake_entraid_sso_integration" {
  name                                = local.resource_names.snowflake.sso_integration
  enabled                             = "true"
  saml2_provider                      = "CUSTOM"
  saml2_issuer                        = "https://sts.windows.net/${var.tenant_id}/"
  saml2_sso_url                       = "https://login.microsoftonline.com/${var.tenant_id}/saml2"
  saml2_x509_cert                     = azuread_service_principal_token_signing_certificate.snowflake_entraid_sso_cert.value
  saml2_sp_initiated_login_page_label = "SAML SSO"
  saml2_enable_sp_initiated           = "true"
  saml2_requested_nameid_format       = "urn:oasis:names:tc:SAML:1.1:nameid-format:emailAddress"
  saml2_snowflake_acs_url             = "https://${lower(data.azurerm_key_vault_secret.snowflake["snowflake-account-identifier"].value)}.${local.resource_names.snowflake.service_urls.svc}/fed/login"
  saml2_snowflake_issuer_url          = "https://${lower(data.azurerm_key_vault_secret.snowflake["snowflake-account-identifier"].value)}.${local.resource_names.snowflake.service_urls.svc}"
  provider                            = snowflake.securityadmin
  depends_on                          = [snowflake_grant_privileges_to_account_role.securityadmin_create_integration]
}
