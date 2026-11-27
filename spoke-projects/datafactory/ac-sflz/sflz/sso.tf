# Entra SAML app + Snowflake SAML security integration for interactive login.
# Public and privatelink each need their own app and integration: Entra appends that app's client id to the issuer, and identifier-first login lets both stay enabled.
locals {
  sso_public_url  = "https://${lower(var.account.identifier)}.${local.resource_names.snowflake.service_urls.public.svc}"
  sso_private_url = "https://${lower(var.account.identifier)}.${local.resource_names.snowflake.service_urls.private.svc}"
}
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
  display_name    = "Snowflake ${lower(var.account.identifier)} SAML SSO"
  description     = "Snowflake ${lower(var.account.identifier)} SAML SSO integration application"
  template_id     = data.azuread_application_template.snowflake_entra_sso.id
  owners          = toset([local.config.projects.azhubs.owner_user.object_id, local.config.projects.azhubs.client.service_principal.object_id])
  identifier_uris = [local.sso_public_url]
  api {
    mapped_claims_enabled          = true
    requested_access_token_version = 2
  }
  logo_image       = filebase64("./snowflake-logo.png")
  sign_in_audience = "AzureADMyOrg"
  feature_tags {
    custom_single_sign_on = true # required for saml
    enterprise            = true
  }
  web {
    redirect_uris = ["${local.sso_public_url}/fed/login"]
    logout_url    = "${local.sso_public_url}/fed/logout"
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
  owners                       = toset([local.config.projects.azhubs.owner_user.object_id, local.config.projects.azhubs.client.service_principal.object_id])
  use_existing                 = true # adopt the principal created by snowflake_entraid_sso_app
  app_role_assignment_required = true
  feature_tags {
    custom_single_sign_on = true # required for saml
    enterprise            = true
  }
  preferred_single_sign_on_mode = "saml"
  login_url                     = local.sso_public_url
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
data "azuread_group" "project_owner" {
  display_name = var.project.owner_group
}
# assign the groups to the app_roles in the sso integration app
resource "azuread_app_role_assignment" "snowflake_entraid_sso_app_roles" {
  for_each            = module.project_roles.by_key
  principal_object_id = var.entra_groups[each.key].object_id
  app_role_id         = random_uuid.project_roles[each.key].id
  resource_object_id  = azuread_service_principal.snowflake_entraid_sso_principal.object_id
}
# Assign `datafactory-owners` the `platform-admin` app role so its members can sign in
resource "azuread_app_role_assignment" "snowflake_entraid_sso_owner" {
  principal_object_id = data.azuread_group.project_owner.object_id
  app_role_id         = random_uuid.project_roles["platform-admin"].id
  resource_object_id  = azuread_service_principal.snowflake_entraid_sso_principal.object_id
}
# Append each app's client id to the SAML issuer so the two integrations can both stay enabled
resource "azuread_claims_mapping_policy" "snowflake_entraid_sso_issuer" {
  display_name = "Snowflake ${lower(var.account.identifier)} append application id to issuer"
  definition = [
    jsonencode({
      ClaimsMappingPolicy = {
        Version                 = 1
        IncludeBasicClaimSet    = "true"
        issuerWithApplicationId = "true"
      }
    })
  ]
}
resource "azuread_service_principal_claims_mapping_policy_assignment" "snowflake_entraid_sso_issuer" {
  claims_mapping_policy_id = azuread_claims_mapping_policy.snowflake_entraid_sso_issuer.id
  service_principal_id     = azuread_service_principal.snowflake_entraid_sso_principal.id
  depends_on               = [azuread_service_principal_token_signing_certificate.snowflake_entraid_sso_cert]
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
  saml2_issuer                        = "https://sts.windows.net/${var.tenant_id}/${azuread_application.snowflake_entraid_sso_app.client_id}"
  saml2_sso_url                       = "https://login.microsoftonline.com/${var.tenant_id}/saml2"
  saml2_x509_cert                     = azuread_service_principal_token_signing_certificate.snowflake_entraid_sso_cert.value
  saml2_sp_initiated_login_page_label = "SAML SSO"
  saml2_enable_sp_initiated           = "true"
  saml2_requested_nameid_format       = "urn:oasis:names:tc:SAML:1.1:nameid-format:emailAddress"
  saml2_snowflake_acs_url             = "${local.sso_public_url}/fed/login"
  saml2_snowflake_issuer_url          = local.sso_public_url
  provider                            = snowflake.securityadmin
  depends_on = [
    snowflake_grant_privileges_to_account_role.securityadmin_create_integration,
    azuread_service_principal_claims_mapping_policy_assignment.snowflake_entraid_sso_issuer,
  ]
}
# Set account parameter `ENABLE_IDENTIFIER_FIRST_LOGIN` so Snowsight asks for the user identifier before the account, and so a second SAML integration can stay enabled
resource "snowflake_account_parameter" "enable_identifier_first_login" {
  key      = "ENABLE_IDENTIFIER_FIRST_LOGIN"
  value    = "true"
  provider = snowflake.accountadmin
}
# Entra app `Snowflake <account> SAML SSO Private Link` for the privatelink account URL
resource "azuread_application" "snowflake_entraid_sso_app_privatelink" {
  display_name    = "Snowflake ${lower(var.account.identifier)} SAML SSO Private Link"
  description     = "Snowflake ${lower(var.account.identifier)} SAML SSO for the privatelink account URL"
  template_id     = data.azuread_application_template.snowflake_entra_sso.id
  owners          = toset([local.config.projects.azhubs.owner_user.object_id, local.config.projects.azhubs.client.service_principal.object_id])
  identifier_uris = [local.sso_private_url]
  api {
    mapped_claims_enabled          = true
    requested_access_token_version = 2
  }
  logo_image       = filebase64("./snowflake-logo.png")
  sign_in_audience = "AzureADMyOrg"
  feature_tags {
    custom_single_sign_on = true
    enterprise            = true
  }
  web {
    redirect_uris = ["${local.sso_private_url}/fed/login"]
    logout_url    = "${local.sso_private_url}/fed/logout"
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
resource "azuread_service_principal" "snowflake_entraid_sso_principal_privatelink" {
  client_id                    = azuread_application.snowflake_entraid_sso_app_privatelink.client_id
  owners                       = toset([local.config.projects.azhubs.owner_user.object_id, local.config.projects.azhubs.client.service_principal.object_id])
  use_existing                 = true
  app_role_assignment_required = true
  feature_tags {
    custom_single_sign_on = true
    enterprise            = true
  }
  preferred_single_sign_on_mode = "saml"
  login_url                     = local.sso_private_url
}
resource "azuread_service_principal_token_signing_certificate" "snowflake_entraid_sso_cert_privatelink" {
  service_principal_id = azuread_service_principal.snowflake_entraid_sso_principal_privatelink.id
  display_name         = "CN=snowflake-entraid-sso-privatelink-cert"
  end_date             = time_offset.snowflake_entraid_sso_cert_end.rfc3339
  lifecycle {
    replace_triggered_by = [
      time_rotating.snowflake_entraid_sso_cert_rotation,
    ]
  }
}
resource "azuread_app_role_assignment" "snowflake_entraid_sso_app_roles_privatelink" {
  for_each            = module.project_roles.by_key
  principal_object_id = var.entra_groups[each.key].object_id
  app_role_id         = random_uuid.project_roles[each.key].id
  resource_object_id  = azuread_service_principal.snowflake_entraid_sso_principal_privatelink.object_id
}
# Assign `datafactory-owners` the `platform-admin` app role on the privatelink app
resource "azuread_app_role_assignment" "snowflake_entraid_sso_owner_privatelink" {
  principal_object_id = data.azuread_group.project_owner.object_id
  app_role_id         = random_uuid.project_roles["platform-admin"].id
  resource_object_id  = azuread_service_principal.snowflake_entraid_sso_principal_privatelink.object_id
}
resource "azuread_service_principal_claims_mapping_policy_assignment" "snowflake_entraid_sso_issuer_privatelink" {
  claims_mapping_policy_id = azuread_claims_mapping_policy.snowflake_entraid_sso_issuer.id
  service_principal_id     = azuread_service_principal.snowflake_entraid_sso_principal_privatelink.id
  depends_on               = [azuread_service_principal_token_signing_certificate.snowflake_entraid_sso_cert_privatelink]
}
# Snowflake integration `INT_SECURITY_SAML_SSO_PRIVATELINK` for the privatelink ACS and issuer URLs
resource "snowflake_saml2_integration" "snowflake_entraid_sso_integration_privatelink" {
  name                                = local.resource_names.snowflake.sso_integration_privatelink
  enabled                             = "true"
  saml2_provider                      = "CUSTOM"
  saml2_issuer                        = "https://sts.windows.net/${var.tenant_id}/${azuread_application.snowflake_entraid_sso_app_privatelink.client_id}"
  saml2_sso_url                       = "https://login.microsoftonline.com/${var.tenant_id}/saml2"
  saml2_x509_cert                     = azuread_service_principal_token_signing_certificate.snowflake_entraid_sso_cert_privatelink.value
  saml2_sp_initiated_login_page_label = "SAML SSO Private Link"
  saml2_enable_sp_initiated           = "true"
  saml2_requested_nameid_format       = "urn:oasis:names:tc:SAML:1.1:nameid-format:emailAddress"
  saml2_snowflake_acs_url             = "${local.sso_private_url}/fed/login"
  saml2_snowflake_issuer_url          = local.sso_private_url
  provider                            = snowflake.securityadmin
  depends_on = [
    snowflake_grant_privileges_to_account_role.securityadmin_create_integration,
    snowflake_account_parameter.enable_identifier_first_login,
    azuread_service_principal_claims_mapping_policy_assignment.snowflake_entraid_sso_issuer_privatelink,
  ]
}
