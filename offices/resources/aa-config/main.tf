data "azurerm_key_vault_secret" "config_init" {
  name         = "${var.project_name}-config"
  key_vault_id = var.corp_vault_id
  provider     = azurerm.corp
}
data "azurerm_key_vault_secret" "config_owner_p12" {
  name         = "${var.project_name}-owner-p12"
  key_vault_id = var.corp_vault_id
  provider     = azurerm.corp
}
data "azurerm_key_vault_secret" "sp1_secrets" {
  for_each = toset([
    "cloudflare-dns-editzonekey",
    "cloudflare-dns-zoneid",
    "nvaAdminUserName",
    "adminPK"
  ])
  name         = each.key
  key_vault_id = var.corp_vault_id
  provider     = azurerm.corp
}
# Get sp1 host addresses that back Cloudflare DNS records.
data "external" "sp1_dns_records" {
  program = ["python3", "${path.module}/addr2dns.py"]
  query = {
    admin_user   = data.azurerm_key_vault_secret.sp1_secrets["nvaAdminUserName"].value
    admin_pk     = data.azurerm_key_vault_secret.sp1_secrets["adminPK"].value
    egx_host     = "egx.${local.org.about.dns_domain}"
    opi_host     = "opi-private-ipv4.${local.org.about.dns_domain}"
    opi_iface    = "end1"
    aliases_json = jsonencode(local.dns_aliases)
  }
}
locals {
  sp1_dns_records = jsondecode(base64decode(data.external.sp1_dns_records.result.records_base64))
}
resource "cloudflare_dns_record" "sp1_dns_records" {
  for_each = local.sp1_dns_records
  zone_id  = data.azurerm_key_vault_secret.sp1_secrets["cloudflare-dns-zoneid"].value
  name     = "${each.value.name}.${local.org.about.dns_domain}"
  content  = each.value.content
  type     = each.value.type
  ttl      = "300"
}
# get let's encrypt certificates for sp1 hosts and store them in the vault
resource "tls_private_key" "acme_account_private_key" {
  algorithm = "RSA"
}
resource "acme_registration" "acme_registration" {
  account_key_pem = tls_private_key.acme_account_private_key.private_key_pem
  email_address   = local.project.owner
}
resource "tls_private_key" "cert_private_key" {
  for_each    = local.sp1_hosts
  algorithm   = "ECDSA"
  ecdsa_curve = "P384"
}
resource "tls_cert_request" "sign_request" {
  for_each        = local.sp1_hosts
  private_key_pem = tls_private_key.cert_private_key[each.key].private_key_pem
  subject {
    common_name = "${each.key}.${local.org.about.dns_domain}"
  }
  dns_names = [
    "${each.key}-ipv4.${local.org.about.dns_domain}",
    "${each.key}-ipv6.${local.org.about.dns_domain}",
    "${each.key}-private.${local.org.about.dns_domain}",
    "${each.key}-private-ipv4.${local.org.about.dns_domain}",
    "${each.key}-private-ipv6.${local.org.about.dns_domain}"
  ]
}
resource "acme_certificate" "xyz9_certs" {
  for_each                      = local.sp1_hosts
  account_key_pem               = acme_registration.acme_registration.account_key_pem
  certificate_request_pem       = tls_cert_request.sign_request[each.key].cert_request_pem
  min_days_remaining            = 30
  revoke_certificate_on_destroy = false # a failed replace must not revoke the cert still on disk
  # The agent resolver is 10.255.255.254 and does not see the public TXT records.
  recursive_nameservers = ["1.1.1.1:53", "8.8.8.8:53"]
  dns_challenge {
    provider = "cloudflare"
    config = {
      CF_ZONE_API_TOKEN = data.azurerm_key_vault_secret.sp1_secrets["cloudflare-dns-editzonekey"].value
      CF_DNS_API_TOKEN  = data.azurerm_key_vault_secret.sp1_secrets["cloudflare-dns-editzonekey"].value
    }
  }
}
# Store certificates in the corporate vault
resource "azurerm_key_vault_certificate" "sp1_certs" {
  for_each     = local.sp1_hosts
  name         = "xyz9sp1-${each.key}-cert"
  key_vault_id = var.corp_vault_id
  certificate {
    contents = format("%s%s",
      acme_certificate.xyz9_certs[each.key].certificate_pem,
      tls_private_key.cert_private_key[each.key].private_key_pem_pkcs8
    )
  }
  provider = azurerm.corp
}
output "sp1_dns_records" {
  value = local.sp1_dns_records
}
# homeapps aa-acme issues the app host certificates with this account.
output "acme_account_key_pem" {
  value     = tls_private_key.acme_account_private_key.private_key_pem
  sensitive = true
}
