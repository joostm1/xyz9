data "azuread_client_config" "current" {}
data "azurerm_subscription" "current" {
  subscription_id = var.subscription_id
}
data "azuread_user" "owner" {
  user_principal_name = local.project.owner
}
resource "tls_private_key" "owner" {
  algorithm = "RSA"
  rsa_bits  = 2048
}
resource "tls_self_signed_cert" "owner" {
  private_key_pem       = tls_private_key.owner.private_key_pem
  validity_period_hours = 87600
  allowed_uses          = ["client_auth", "digital_signature", "key_encipherment"]
  subject {
    common_name  = "${var.project_name}-owner.${local.org.about.dns_domain}"
    organization = local.org.about.x509.org
  }
}
resource "tls_private_key" "project_ca" {
  algorithm = "RSA"
  rsa_bits  = 2048
}
resource "tls_self_signed_cert" "project_ca" {
  private_key_pem       = tls_private_key.project_ca.private_key_pem
  validity_period_hours = local.org.about.x509.ca.validity_period_hours
  is_ca_certificate     = true
  allowed_uses          = ["cert_signing", "crl_signing", "digital_signature"]
  subject {
    common_name  = local.org.about.x509.ca.common_name
    organization = local.org.about.x509.org
    country      = local.org.about.x509.ca.country
  }
}
# Create the `azhubs-owner` application and the `datacenter-owners` group that later roots authenticate as
resource "azuread_application" "owner" {
  display_name = "${var.project_name}-owner"
  owners       = [data.azuread_user.owner.object_id]
}
resource "azuread_service_principal" "owner" {
  client_id = azuread_application.owner.client_id
  owners    = [data.azuread_user.owner.object_id]
}
resource "azuread_application_certificate" "owner" {
  application_id = azuread_application.owner.id
  type           = "AsymmetricX509Cert"
  value          = tls_self_signed_cert.owner.cert_pem
}
resource "azuread_group" "owner" {
  display_name     = local.project.owner_group
  security_enabled = true
  owners           = [data.azuread_user.owner.object_id]
  members          = [data.azuread_user.owner.object_id, azuread_service_principal.owner.object_id]
}
data "external" "owner_p12" {
  program = ["python3", "${path.module}/pkcs12.py"]
  query = {
    cert_pem = tls_self_signed_cert.owner.cert_pem
    key_pem  = tls_private_key.owner.private_key_pem_pkcs8
  }
}
# Import `azhubs-owner` into `xz9kviac` as PEM. Key Vault's certificate import rejects a PKCS#12 body.
resource "azurerm_key_vault_certificate" "owner" {
  name         = "${var.project_name}-owner"
  key_vault_id = var.corp_vault_id
  provider     = azurerm.corp
  certificate {
    contents = base64encode("${tls_self_signed_cert.owner.cert_pem}${tls_private_key.owner.private_key_pem_pkcs8}")
  }
}
# Store `azhubs-owner-p12` for client_certificate. That argument base64-decodes a PKCS#12, and the certificate secret above is PEM.
resource "azurerm_key_vault_secret" "owner_p12" {
  name         = "${var.project_name}-owner-p12"
  value        = data.external.owner_p12.result.p12_b64
  key_vault_id = var.corp_vault_id
  content_type = "application/x-pkcs12"
  provider     = azurerm.corp
}
# Import the `azhubs-ca` project CA into `xz9kviac` so later roots can sign with its key
resource "azurerm_key_vault_certificate" "project_ca" {
  name         = "${var.project_name}-ca"
  key_vault_id = var.corp_vault_id
  provider     = azurerm.corp
  certificate {
    contents = base64encode("${tls_self_signed_cert.project_ca.cert_pem}${tls_private_key.project_ca.private_key_pem_pkcs8}")
  }
}
module "scope_roles" {
  source          = "../../catalog/terraform/modules/scope_enumerator"
  tree            = local.config.scopes
  enum_key        = "roles"
  enum_value_name = "value"
  segment_translations = {
    locations = ""
  }
}
# functional scope/role groups
resource "azuread_group" "function_scope_role_groups" {
  for_each                = local.scope_role_groups
  display_name            = each.value.display_name
  description             = each.value.description
  security_enabled        = true
  assignable_to_role      = false
  prevent_duplicate_names = true
  owners = [
    local.config.projects.projects.identity.owner.user_object_id,
    local.config.projects.projects.identity.owner.app_object_id
  ]
}
# main resource group for the project
resource "azurerm_resource_group" "project_rg" {
  location = local.config.azure.rg.location
  name     = local.config.azure.rg.name
}
# Grant `datacenter-owners` Owner on `rg-azhubs` so the owner application can manage it
resource "azurerm_role_assignment" "owner_group_rg" {
  scope                = azurerm_resource_group.project_rg.id
  role_definition_name = "Owner"
  principal_id         = azuread_group.owner.object_id
  principal_type       = "Group"
}
# Grant `datacenter-owners` Owner on subscription `xyz9-iac` so the owner application can create hub resource groups such as `rg-azhubs-apc1`
resource "azurerm_role_assignment" "owner_group_subscription" {
  scope                = data.azurerm_subscription.current.id
  role_definition_name = "Owner"
  principal_id         = azuread_group.owner.object_id
  principal_type       = "Group"
}
# role assignments on the resource group
module "rg_role_assignments" {
  source           = "../../catalog/terraform/modules/az/role_assignments"
  entra_groups     = local.entra_scope_role_groups
  assignment_scope = azurerm_resource_group.project_rg.id
  role_assignments = {
    project = {
      admin = {
        "Owner" = true
      }
    }
  }
}
# vault for the project
resource "azurerm_key_vault" "project_kv" {
  name                       = "kv-${local.org.name}-${var.project_name}"
  location                   = azurerm_resource_group.project_rg.location
  resource_group_name        = azurerm_resource_group.project_rg.name
  tenant_id                  = data.azuread_client_config.current.tenant_id
  sku_name                   = "standard"
  purge_protection_enabled   = false
  soft_delete_retention_days = 7
  rbac_authorization_enabled = true
}
# system role assignments on the vault
resource "azurerm_role_assignment" "project_kv_data_roles" {
  for_each = {
    "owner" = {
      principal            = local.config.projects.projects.identity.owner.group_object_id
      role_definition_name = "Key Vault Administrator"
    }
  }
  scope                = azurerm_key_vault.project_kv.id
  role_definition_name = each.value.role_definition_name
  principal_id         = each.value.principal
  principal_type       = "Group"
}
# functional role assignments on the vault
module "kv_role_assignments" {
  source           = "../../catalog/terraform/modules/az/role_assignments"
  entra_groups     = local.entra_scope_role_groups
  assignment_scope = azurerm_key_vault.project_kv.id
  role_assignments = {
    project = {
      admin = {
        "Key Vault Administrator" = true
      }
      engineer = {
        "Key Vault Administrator" = true
      }
    }
  }
}
# private dns zones for the project
resource "azurerm_private_dns_zone" "privatedns" {
  for_each            = toset(local.config.azure.private_dns_zones)
  name                = each.key
  resource_group_name = azurerm_resource_group.project_rg.name
}
