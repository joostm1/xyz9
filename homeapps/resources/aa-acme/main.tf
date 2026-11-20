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
    "nvaAdminUserName",
    "adminPK",
  ])
  name         = each.key
  key_vault_id = var.corp_vault_id
  provider     = azurerm.corp
}
# offices aa-config owns the Let's Encrypt account. This root issues the app host certificates.
data "terraform_remote_state" "offices_config" {
  backend = "azurerm"
  config = {
    resource_group_name  = var.resource_group_name
    storage_account_name = var.storage_account_name
    container_name       = "offices"
    key                  = "aa-config.tfstate"
    use_azuread_auth     = true
    tenant_id            = var.tenant_id
    subscription_id      = var.subscription_id
  }
}
resource "tls_private_key" "cert_private_key" {
  for_each    = local.app_hosts
  algorithm   = "ECDSA"
  ecdsa_curve = "P384"
}
resource "tls_cert_request" "sign_request" {
  for_each        = local.app_hosts
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
  for_each                      = local.app_hosts
  account_key_pem               = data.terraform_remote_state.offices_config.outputs.acme_account_key_pem
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
resource "azurerm_key_vault_certificate" "sp1_certs" {
  for_each     = local.app_hosts
  name         = "${var.project_name}-${each.key}-cert"
  key_vault_id = var.corp_vault_id
  certificate {
    contents = format("%s%s",
      acme_certificate.xyz9_certs[each.key].certificate_pem,
      tls_private_key.cert_private_key[each.key].private_key_pem_pkcs8
    )
  }
  provider = azurerm.corp
}
# Install ACME PEMs under docker.host.tls_root on OPI (compose mounts those paths).
# unifi's Java keystore import stays deferred; nginx serves unifi/fullchain.pem.
module "opi_tls_files" {
  source      = "${local.org_folder}/terraform/modules/remote_files"
  name        = "opi-tls"
  remote_root = local.docker.host.tls_root
  connection  = local.opi_ssh
  directories = { for host in local.app_hosts : host => { mode = "0755" } } # ha/fullchain.pem -> ha
  files = merge([
    for host in local.app_hosts : {
      "${host}/fullchain.pem" = {
        # certificate_pem is the leaf; issuer_pem is the intermediate
        content = format("%s%s",
          acme_certificate.xyz9_certs[host].certificate_pem,
          acme_certificate.xyz9_certs[host].issuer_pem
        )
        mode = "0644"
      }
      "${host}/privkey.pem" = {
        content = tls_private_key.cert_private_key[host].private_key_pem
        mode    = "0600"
      }
    }
  ]...)
  # nginx caches PEMs until reload. Skip when it is not running; a later start reads the files just written.
  remote_commands = [
    "running=$(docker ps -q --filter status=running --filter name=^nginx$); if [ -n \"$running\" ]; then docker exec nginx nginx -s reload; fi",
  ]
}
