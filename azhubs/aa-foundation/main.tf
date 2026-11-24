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
resource "azurerm_key_vault_certificate" "owner" {
  name         = "${var.project_name}-owner"
  key_vault_id = var.corp_vault_id
  provider     = azurerm.corp
  certificate {
    contents = base64encode("${tls_self_signed_cert.owner.cert_pem}${tls_private_key.owner.private_key_pem_pkcs8}")
  }
}
resource "azurerm_key_vault_secret" "owner_p12" {
  name         = "${var.project_name}-owner-p12"
  value        = data.external.owner_p12.result.p12_b64
  key_vault_id = var.corp_vault_id
  content_type = "application/x-pkcs12"
  provider     = azurerm.corp
}
resource "azurerm_key_vault_certificate" "project_ca" {
  name         = "${var.project_name}-ca"
  key_vault_id = var.corp_vault_id
  provider     = azurerm.corp
  certificate {
    contents = base64encode("${tls_self_signed_cert.project_ca.cert_pem}${tls_private_key.project_ca.private_key_pem_pkcs8}")
  }
}
resource "azurerm_role_assignment" "owner_group_subscription" {
  scope                = "/subscriptions/${local.project.azure.subscription_id}"
  role_definition_name = "Owner"
  principal_id         = azuread_group.owner.object_id
  principal_type       = "Group"
  provider             = azurerm.corp
}
