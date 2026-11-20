# create resources for each project

data "azurerm_subscriptions" "available" {}
data "azuread_application_published_app_ids" "well_known" {}
data "azuread_service_principal" "msgraph" {
  client_id = data.azuread_application_published_app_ids.well_known.result.MicrosoftGraph
}
data "azuread_user" "project_owner" {
  user_principal_name = var.project.config.owner
}

# application + principal to be the creator of resources for this/that project
resource "azuread_application" "project_owner_app" {
  display_name = "projects-${var.project.name}-owner"
  owners = [
    var.aa_self_config.identity.owner.app_object_id,
    data.azuread_user.project_owner.object_id
  ]
  sign_in_audience        = "AzureADMyOrg"
  prevent_duplicate_names = true
  tags = [
    "HideApp:false",
    "WindowsAzureActiveDirectoryIntegratedApp"
  ]
  # Request the application permissions, needs consent from `azuread_app_role_assignment`
  required_resource_access {
    resource_app_id = data.azuread_application_published_app_ids.well_known.result["MicrosoftGraph"]
    dynamic "resource_access" {
      for_each = toset(var.project.graph_permissions)
      content {
        id   = data.azuread_service_principal.msgraph.app_role_ids[resource_access.value]
        type = "Role"
      }
    }
  }
}
resource "azuread_service_principal" "project_owner_sp" {
  client_id                    = azuread_application.project_owner_app.client_id
  app_role_assignment_required = false
  owners = [
    var.aa_self_config.identity.owner.app_object_id,
    data.azuread_user.project_owner.object_id
  ]
  description = "Principal for the '${var.project.name}' project: configuration owner and Azure DevOps project administrator."
}
# assign + consent the permissions for the owner application
resource "azuread_app_role_assignment" "projects_owner_app_role_assignments" {
  for_each            = var.project.graph_permissions
  principal_object_id = azuread_service_principal.project_owner_sp.object_id
  app_role_id         = data.azuread_service_principal.msgraph.app_role_ids[each.key]
  resource_object_id  = data.azuread_service_principal.msgraph.object_id
}
# group with owner user and app
resource "azuread_group" "project_owner_group" {
  display_name            = "${var.project.name}-owners"
  security_enabled        = true
  assignable_to_role      = false
  prevent_duplicate_names = true
  owners = [
    data.azuread_user.project_owner.object_id,
    azuread_service_principal.project_owner_sp.object_id
  ]
  members = [
    data.azuread_user.project_owner.object_id,
    azuread_service_principal.project_owner_sp.object_id
  ]
}
# ADO identities. Adopt an existing project; create the name when it is missing.
resource "azuredevops_service_principal_entitlement" "project_owner" {
  count                = var.needs_devops_entitlement ? 1 : 0
  origin_id            = azuread_service_principal.project_owner_sp.object_id
  origin               = "aad"
  account_license_type = "express" # Basic in ADO UI; avoid "basic" on create
}
resource "azuredevops_project" "project" {
  count              = local.has_devops ? 1 : 0
  name               = var.project.config.devops.project.name
  description        = try(var.project.config.description, null)
  visibility         = "private"
  version_control    = "Git"
  work_item_template = "Agile"
  lifecycle {
    ignore_changes = [description] # adopted project keeps its current description
  }
}
data "azuredevops_group" "project_administrators" {
  count      = var.existing_devops_project_id != null ? 1 : 0
  project_id = var.existing_devops_project_id
  name       = "Project Administrators"
}
data "azuredevops_group" "new_project_administrators" {
  count      = local.has_devops && var.existing_devops_project_id == null ? 1 : 0
  project_id = azuredevops_project.project[0].id
  name       = "Project Administrators"
}
resource "azuredevops_group_membership" "project_owner_admin" {
  count = local.has_devops && !local.external_devops_owner ? 1 : 0
  group = try(data.azuredevops_group.project_administrators[0].descriptor, data.azuredevops_group.new_project_administrators[0].descriptor)
  members = [
    azuredevops_service_principal_entitlement.project_owner[0].descriptor
  ]
  mode = "add"
}
## subscription for the project
# resource "azurerm_subscription" "project" {
#   subscription_name = "project-${var.project_name}"
#   workload          = "Production"
#   billing_scope_id  = data.azurerm_billing_mca_account_scope.xyz9.id
#   alias             = var.project_name
# }
resource "azurerm_role_assignment" "project_subscription_owner" {
  scope                = local.projects_subscription_id # cheap ass - use _the holey msdn subscription_ for all projects
  role_definition_name = "Owner"
  principal_id         = azuread_group.project_owner_group.object_id
  principal_type       = "Group"
  description          = "Grant the project owner group ownership on the project subscription"
  provider             = azurerm.iac
}
# Signing cert for the project
resource "tls_private_key" "project_ca_key" {
  algorithm   = "ECDSA"
  ecdsa_curve = "P384"
}
resource "tls_cert_request" "project_ca_sr" {
  private_key_pem = tls_private_key.project_ca_key.private_key_pem
  subject {
    organization = var.org.about.x509.org
    country      = var.org.about.x509.ca.country
    common_name  = "${var.org.about.x509.org} CA for the ${var.project.name} project"
  }
}
resource "tls_locally_signed_cert" "project_ca_cert" {
  cert_request_pem   = tls_cert_request.project_ca_sr.cert_request_pem
  ca_private_key_pem = var.project.ca.key
  ca_cert_pem        = var.project.ca.pem
  is_ca_certificate  = true
  set_subject_key_id = true

  validity_period_hours = 365 * 24
  early_renewal_hours   = 180 * 24
  allowed_uses = [
    "digital_signature",
    "cert_signing",
    "crl_signing",
  ]
}
resource "azurerm_key_vault_certificate" "project_ca_cert_vault" {
  name         = "${var.project.name}-ca"
  key_vault_id = var.corp.vault_id
  certificate {
    contents = format("%s%s%s",
      tls_locally_signed_cert.project_ca_cert.cert_pem,
      tls_private_key.project_ca_key.private_key_pem_pkcs8,
      var.project.ca.pem
    )
  }
  provider = azurerm.iac
}
# cert for the owner app
resource "tls_private_key" "project_owner_key" {
  algorithm = "RSA"
  rsa_bits  = 2048
}
resource "tls_cert_request" "project_owner_sr" {
  private_key_pem = tls_private_key.project_owner_key.private_key_pem
  subject {
    organization = var.org.about.x509.org
    country      = var.org.about.x509.ca.country
    common_name  = "project ${var.project.name} owner"
  }
}
resource "tls_locally_signed_cert" "project_owner_cert" {
  cert_request_pem      = tls_cert_request.project_owner_sr.cert_request_pem
  ca_private_key_pem    = var.project.ca.key
  ca_cert_pem           = var.project.ca.pem
  is_ca_certificate     = false
  set_subject_key_id    = true
  validity_period_hours = 365 * 24
  early_renewal_hours   = 180 * 24
  allowed_uses = [
    "digital_signature",
    "key_encipherment",
    "data_encipherment",
  ]
}
resource "azurerm_key_vault_certificate" "project_owner_cert" {
  name         = "${var.project.name}-owner"
  key_vault_id = var.corp.vault_id
  certificate {
    contents = format("%s%s%s",
      tls_locally_signed_cert.project_owner_cert.cert_pem,
      tls_private_key.project_owner_key.private_key_pem_pkcs8,
      var.project.ca.pem
    )
  }
  provider = azurerm.iac
}
# pkcs12 bundle for azure(rm|ad) and ado
resource "pkcs12_from_pem" "project_owner_p12" {
  cert_pem        = tls_locally_signed_cert.project_owner_cert.cert_pem
  ca_pem          = tls_locally_signed_cert.project_ca_cert.cert_pem
  private_key_pem = tls_private_key.project_owner_key.private_key_pem
  password        = ""
}
# store the pkcs12 bundle as a secret
resource "azurerm_key_vault_secret" "project_owner_p12" {
  name         = "${var.project.name}-owner-p12"
  value        = pkcs12_from_pem.project_owner_p12.result
  key_vault_id = var.corp.vault_id
  content_type = "application/x-pkcs12"
  provider     = azurerm.iac
}
# authenticate the owner with the certificate
resource "azuread_service_principal_certificate" "project_owner_sp_cert" {
  service_principal_id = azuread_service_principal.project_owner_sp.id
  end_date             = tls_locally_signed_cert.project_owner_cert.validity_end_time
  value                = tls_locally_signed_cert.project_owner_cert.cert_pem
  type                 = "AsymmetricX509Cert"
  encoding             = "pem"
  lifecycle {
    ignore_changes = [
      end_date
    ]
  }
}
# iac owns backend containers; projects grants its owner group access.
data "azurerm_storage_container" "project_state_container" {
  name               = var.project.name
  storage_account_id = var.corp.storage_id
  provider           = azurerm.iac
}
removed {
  from = azurerm_storage_container.project_state_container
  lifecycle {
    destroy = false
  }
}
# grant the owner group permissions to the resources created for the project
resource "azurerm_role_assignment" "owner_permissions" {
  for_each = {
    config = {
      scope       = azurerm_key_vault_secret.project_config.resource_versionless_id
      role        = "Key Vault Secrets Officer"
      description = "Grant the project owner group ${azuread_group.project_owner_group.display_name} read access to ${azurerm_key_vault_secret.project_config.resource_versionless_id} vault resource"
    }
    project_ca_cert = {
      scope       = azurerm_key_vault_certificate.project_ca_cert_vault.resource_manager_versionless_id
      role        = "Key Vault Certificate User"
      description = "Grant the project owner group ${azuread_group.project_owner_group.display_name} read access to ${azurerm_key_vault_certificate.project_ca_cert_vault.resource_manager_versionless_id} vault resource"
    }
    project_ca_key = {
      scope       = replace(azurerm_key_vault_certificate.project_ca_cert_vault.resource_manager_versionless_id, "certificates", "secrets")
      role        = "Key Vault Secrets User"
      description = "Grant the project owner group ${azuread_group.project_owner_group.display_name} read access to ${azurerm_key_vault_certificate.project_ca_cert_vault.resource_manager_versionless_id} key resource"
    }
    owner_cert = {
      scope       = azurerm_key_vault_certificate.project_owner_cert.resource_manager_versionless_id
      role        = "Key Vault Certificate User"
      description = "Grant the project owner group ${azuread_group.project_owner_group.display_name} read access to ${azurerm_key_vault_certificate.project_owner_cert.resource_manager_versionless_id} vault resource"
    }
    owner_p12 = {
      scope       = azurerm_key_vault_secret.project_owner_p12.resource_versionless_id
      role        = "Key Vault Secrets User"
      description = "Grant the project owner group ${azuread_group.project_owner_group.display_name} read access to ${azurerm_key_vault_secret.project_owner_p12.resource_versionless_id} vault resource"
    }
    state_container = {
      scope       = data.azurerm_storage_container.project_state_container.id
      role        = "Storage Blob Data Contributor"
      description = "Grant the project owner group ${azuread_group.project_owner_group.display_name} access to ${data.azurerm_storage_container.project_state_container.id}"
    }
    iac_kv_read = {
      scope       = var.corp.vault_id
      role        = "Reader"
      description = "Grant the project owner group ${azuread_group.project_owner_group.display_name} read access on the vault ${var.corp.vault_id}"
    }
  }
  scope                = each.value.scope
  description          = each.value.description
  role_definition_name = each.value.role
  principal_id         = azuread_group.project_owner_group.object_id
  principal_type       = "Group"
  provider             = azurerm.iac
}
data "http" "openid_configuration" {
  url = "https://login.microsoftonline.com/${data.azurerm_subscriptions.available.subscriptions[0].tenant_id}/v2.0/.well-known/openid-configuration"
}
# Project-boundary handover: preserve catalog fields and nest contributor under projects[contributor_project_name]
resource "azurerm_key_vault_secret" "project_config" {
  name = "${var.project.name}-config"
  value = jsonencode(merge(var.project.config, {
    projects = merge(try(var.project.config.projects, {}), {
      (var.contributor_project_name) = merge(
        {
          identity = {
            owner = {
              user_object_id  = data.azuread_user.project_owner.object_id
              app_object_id   = azuread_service_principal.project_owner_sp.object_id
              app_client_id   = azuread_service_principal.project_owner_sp.client_id
              group_object_id = azuread_group.project_owner_group.object_id
            }
          }
          secret_names = {
            certs = {
              project_ca = azurerm_key_vault_certificate.project_ca_cert_vault.name
              owner_cert = azurerm_key_vault_certificate.project_owner_cert.name
            }
            secrets = {
              owner_p12 = azurerm_key_vault_secret.project_owner_p12.name
            }
          }
          azurerm = {
            mg = var.aa_self_config.azurerm.project.mg # our predecessor
            subscription = {
              id   = local.projects_subscription.id
              name = local.projects_subscription.name
            }
          }
          entra = {
            tenant_id            = data.azurerm_subscriptions.available.subscriptions[0].tenant_id
            openid_configuration = jsondecode(data.http.openid_configuration.response_body)
          }
        },
        local.has_devops ? {
          devops = {
            project = {
              id   = azuredevops_project.project[0].id
              name = azuredevops_project.project[0].name
            }
          }
        } : {}
      )
    })
  }))
  key_vault_id = var.corp.vault_id
  content_type = "application/json"
  provider     = azurerm.iac
}
