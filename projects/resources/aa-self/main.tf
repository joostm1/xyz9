
data "azuread_client_config" "current" {}
data "azurerm_client_config" "current" {}
data "azurerm_subscriptions" "available" {}
data "azuread_application_published_app_ids" "well_known" {}
data "azuread_service_principal" "msgraph" {
  client_id = data.azuread_application_published_app_ids.well_known.result.MicrosoftGraph
}
data "azuread_user" "owner" {
  user_principal_name = local.project.owner # friend & trustee of corp
}
# org CA
data "azurerm_key_vault_certificate_data" "org_ca" {
  name         = "xyz9-ca"
  key_vault_id = var.corp_vault_id
}
data "azurerm_key_vault_secret" "billing_account" {
  name         = "xyz9-billing-account"
  key_vault_id = var.corp_vault_id
}
data "azurerm_billing_mca_account_scope" "xyz9" {
  billing_account_name = jsondecode(data.azurerm_key_vault_secret.billing_account.value).account_name
  billing_profile_name = jsondecode(data.azurerm_key_vault_secret.billing_account.value).profile_name
  invoice_section_name = jsondecode(data.azurerm_key_vault_secret.billing_account.value).invoice_section_name
}
# projects management group
resource "azurerm_management_group" "projects" {
  display_name               = "projects"
  name                       = "projects"
  parent_management_group_id = "/providers/Microsoft.Management/managementGroups/mg1"
}
resource "azurerm_management_group_subscription_association" "projects" {
  management_group_id = azurerm_management_group.projects.id
  subscription_id     = local.subscriptions_map[local.projects_subscription_name].id
}
# subscription for the project
resource "azurerm_subscription" "project" {
  subscription_name = "sub-${var.project_name}"
  workload          = "Production" # or "DevTest"
  billing_scope_id  = data.azurerm_billing_mca_account_scope.xyz9.id
  alias             = "sub-${var.project_name}"
}
resource "azurerm_management_group_subscription_association" "project" {
  management_group_id = azurerm_management_group.projects.id
  subscription_id     = "/subscriptions/${azurerm_subscription.project.subscription_id}"
}
# key for project CA
resource "tls_private_key" "project_ca_key" {
  algorithm   = "ECDSA"
  ecdsa_curve = "P384"
}
# sign request for the project CA
resource "tls_cert_request" "project_ca_sr" {
  private_key_pem = tls_private_key.project_ca_key.private_key_pem
  subject {
    organization = local.org.about.x509.org
    country      = local.org.about.x509.ca.country
    common_name  = "${local.org.about.x509.org} CA for the `{var.project_name}` project"
  }
}
# CA for this project
resource "tls_locally_signed_cert" "project_ca" {
  cert_request_pem      = tls_cert_request.project_ca_sr.cert_request_pem
  ca_private_key_pem    = data.azurerm_key_vault_certificate_data.org_ca.key
  ca_cert_pem           = data.azurerm_key_vault_certificate_data.org_ca.pem
  is_ca_certificate     = true
  set_subject_key_id    = true
  validity_period_hours = 365 * 24
  early_renewal_hours   = 180 * 24
  allowed_uses = [
    "digital_signature",
    "cert_signing",
    "crl_signing",
  ]
}
# store the project CA in the corporate vault
resource "azurerm_key_vault_certificate" "project_ca" {
  name         = "${var.project_name}-ca"
  key_vault_id = var.corp_vault_id
  certificate {
    contents = format("%s%s%s",
      tls_locally_signed_cert.project_ca.cert_pem,
      tls_private_key.project_ca_key.private_key_pem_pkcs8,
      data.azurerm_key_vault_certificate_data.org_ca.pem
    )
  }
}
# key for the owner identity
resource "tls_private_key" "owner_key" {
  algorithm = "RSA"
  rsa_bits  = 2048
}
# sign request for the owner identity
resource "tls_cert_request" "owner_sr" {
  private_key_pem = tls_private_key.owner_key.private_key_pem
  subject {
    organization = local.org.about.x509.org
    country      = local.org.about.x509.ca.country
    common_name  = "project ${local.project.name} owner"
  }
}
# certificate for the owner identity, signed by the project CA
resource "tls_locally_signed_cert" "owner_cert" {
  cert_request_pem      = tls_cert_request.owner_sr.cert_request_pem
  ca_private_key_pem    = tls_private_key.project_ca_key.private_key_pem
  ca_cert_pem           = tls_locally_signed_cert.project_ca.cert_pem
  is_ca_certificate     = false
  set_subject_key_id    = true
  validity_period_hours = 365 * 24
  early_renewal_hours   = 180 * 24
  allowed_uses = [
    "digital_signature",
    "cert_signing",
    "crl_signing",
  ]
}
# store the owner certificate in the corporate vault
resource "azurerm_key_vault_certificate" "owner_cert" {
  name         = "${var.project_name}-owner"
  key_vault_id = var.corp_vault_id
  certificate {
    contents = format("%s%s",
      tls_locally_signed_cert.owner_cert.cert_pem,
      tls_private_key.owner_key.private_key_pem_pkcs8
    )
  }
}
# azure[rm|ad] providers require pkcs12 for certificate authentication,
#  create a PKCS12 bundle with the certificate and private key
resource "pkcs12_from_pem" "owner_p12" {
  cert_pem        = tls_locally_signed_cert.owner_cert.cert_pem
  ca_pem          = tls_locally_signed_cert.project_ca.cert_pem
  private_key_pem = tls_private_key.owner_key.private_key_pem
  password        = ""
}
# store the pkcs12 bundle in the corporate vault as a secret
resource "azurerm_key_vault_secret" "owner_p12" {
  name         = "${var.project_name}-owner-p12"
  value        = pkcs12_from_pem.owner_p12.result
  key_vault_id = var.corp_vault_id
  content_type = "application/x-pkcs12"
}
# application + principal to be the creator of the project configuration resources
resource "azuread_application" "owner" {
  display_name            = "${var.project_name}-owner"
  owners                  = [data.azuread_user.owner.object_id]
  sign_in_audience        = "AzureADMyOrg"
  prevent_duplicate_names = true
  tags = [
    "HideApp:false",
    "WindowsAzureActiveDirectoryIntegratedApp:true"
  ]
  # Grant the application required MsGraph permissions, pretty much `global admin`
  required_resource_access {
    resource_app_id = data.azuread_application_published_app_ids.well_known.result["MicrosoftGraph"]
    dynamic "resource_access" {
      for_each = toset(local.projectsOwnerGraphPermissions)
      content {
        id   = data.azuread_service_principal.msgraph.app_role_ids[resource_access.value]
        type = "Role"
      }
    }
  }
}
# service principal to represent the owner application
resource "azuread_service_principal" "owner" {
  client_id                    = azuread_application.owner.client_id
  app_role_assignment_required = false
  owners                       = [data.azuread_user.owner.object_id]
  description                  = "Principal for the '${var.project_name}' project: configuration owner and Azure DevOps org provisioner (PCA) for project-scoped principals and ADO projects."
}
# Add owner SP to the Azure DevOps org as a Basic user and Project Collection Administrator
resource "azuredevops_service_principal_entitlement" "owner" {
  origin_id            = azuread_service_principal.owner.object_id
  origin               = "aad"
  account_license_type = "express" # Basic in the ADO UI
}
data "azuredevops_group" "project_collection_administrators" {
  name = "Project Collection Administrators"
}
resource "azuredevops_group_membership" "owner_pca" {
  group = data.azuredevops_group.project_collection_administrators.descriptor
  members = [
    azuredevops_service_principal_entitlement.owner.descriptor
  ]
  mode = "add"
}
# admin-consent the permissions for the owner application
resource "azuread_app_role_assignment" "owner_role_assignment" {
  for_each            = toset(local.projectsOwnerGraphPermissions)
  principal_object_id = azuread_service_principal.owner.object_id
  app_role_id         = data.azuread_service_principal.msgraph.app_role_ids[each.key]
  resource_object_id  = data.azuread_service_principal.msgraph.object_id
}
# authenticate the owner with the certificate
resource "azuread_service_principal_certificate" "owner" {
  service_principal_id = azuread_service_principal.owner.id
  type                 = "AsymmetricX509Cert"
  value                = azurerm_key_vault_certificate.owner_cert.certificate_data
  encoding             = "hex"
  end_date             = tls_locally_signed_cert.owner_cert.validity_end_time
  lifecycle {
    ignore_changes = [
      end_date
    ]
  }
}
# Create the owner group for the project with the human as owner and both the human and app as members
resource "azuread_group" "owner_group" {
  display_name            = local.project.owner_group
  security_enabled        = true
  assignable_to_role      = false
  prevent_duplicate_names = true
  owners = [
    data.azuread_user.owner.object_id,
    azuread_service_principal.owner.object_id
  ]
  members = [
    data.azuread_user.owner.object_id,
    azuread_service_principal.owner.object_id
  ]
}
resource "azurerm_role_assignment" "projects_owner" {
  for_each = {
    corp_vault_kvadmin = {
      scope                = var.corp_vault_id
      role_definition_name = "Key Vault Administrator"
      description          = "Grant the project owner group ownership corp vault"
    }
    corp_vault_owner = {
      scope                = var.corp_vault_id
      role_definition_name = "Owner"
      description          = "Grant the project owner group ownership corp vault"
    }
    corp_storage = {
      scope                = var.corp_storage_id
      role_definition_name = "Owner"
      description          = "Grant the project owner group ownership corp storage"
    }
    corp_storage_data = {
      scope                = var.corp_storage_id
      role_definition_name = "Storage Blob Data Owner"
      description          = "Grant the project owner group ownership corp storage data"
    }
    subscription = {
      scope                = "/subscriptions/${azurerm_subscription.project.subscription_id}"
      role_definition_name = "Owner"
      description          = "Grant the project owner group ownership on the ${var.project_name} subscription"
    }
    subscription_iac = {
      scope                = "/subscriptions/${local.subscriptions_map["xyz9-iac"].subscription_id}"
      role_definition_name = "Reader"
      description          = "Grant the project owner group Reader role on the 'xyz9-iac' subscription"
    }
    subscription_shared = {
      scope                = local.subscriptions_map[local.projects_subscription_name].id
      role_definition_name = "Owner"
      description          = "Grant the project owner group ownership on the shared ${local.projects_subscription_name} subscription"
    }
    management_group_owner = {
      scope                = azurerm_management_group.projects.id
      role_definition_name = "Owner"
      description          = "Grant the project owner group ${azuread_group.owner_group.display_name} Owner role on the projects management group"
    }
  }
  scope                = each.value.scope
  role_definition_name = each.value.role_definition_name
  principal_id         = azuread_group.owner_group.object_id
  principal_type       = "Group"
  description          = each.value.description
}
