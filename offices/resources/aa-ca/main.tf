resource "tls_private_key" "cakey" {
  algorithm = "RSA"
  rsa_bits  = 2048
}
resource "tls_self_signed_cert" "cacert" {
  private_key_pem       = tls_private_key.cakey.private_key_pem
  is_ca_certificate     = true
  validity_period_hours = local.org.about.x509.ca.validity_period_hours
  allowed_uses = [
    "digital_signature",
    "cert_signing",
    "crl_signing",
  ]
  subject {
    country      = local.org.about.x509.ca.country
    common_name  = local.org.about.x509.ca.common_name
    organization = local.org.about.x509.org
  }
}
resource "azurerm_key_vault_certificate" "ca" {
  name         = local.org.about.x509.ca.vault_name
  key_vault_id = var.corp_vault_id
  certificate {
    contents = format("%s%s",
      tls_self_signed_cert.cacert.cert_pem,
      tls_private_key.cakey.private_key_pem_pkcs8
    )
  }
}
