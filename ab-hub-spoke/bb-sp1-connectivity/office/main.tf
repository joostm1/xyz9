# office IPsec identity cert, signed by the datacenter project CA
resource "tls_private_key" "ipsec_key" {
  algorithm = "RSA"
  rsa_bits  = 2048
}
resource "tls_cert_request" "ipsec_csr" {
  private_key_pem = tls_private_key.ipsec_key.private_key_pem
  dns_names = [
    "${local.router}.${local.domain}",
    "${local.router}-ipv4.${local.domain}",
    "${local.router}-ipv6.${local.domain}",
    "${local.router}-private.${local.domain}",
    "${local.router}-private-ipv4.${local.domain}",
    "${local.router}-private-ipv6.${local.domain}",
  ]
  subject {
    organization = var.config.org.about.x509.org
    country      = var.config.org.about.x509.ca.country
    common_name  = "${local.router}.${local.domain}"
  }
}
resource "tls_locally_signed_cert" "ipsec_cert" {
  cert_request_pem      = tls_cert_request.ipsec_csr.cert_request_pem
  ca_private_key_pem    = var.config.project_ca.key
  ca_cert_pem           = var.config.project_ca.pem
  validity_period_hours = 43800
  allowed_uses = [
    "digital_signature",
    "key_encipherment",
    "server_auth",
    "client_auth",
  ]
}
resource "azurerm_key_vault_certificate" "ipsec_cert" {
  name         = "${local.router}-ipsec-cert"
  key_vault_id = var.config.project.vault.id
  certificate {
    contents = format("%s%s",
      tls_locally_signed_cert.ipsec_cert.cert_pem,
      tls_private_key.ipsec_key.private_key_pem_pkcs8
    )
  }
}
module "ipsec_mesh" {
  source   = "../../shared/ipsec_mesh"
  me       = local.me
  members  = var.members
  cert_pem = tls_locally_signed_cert.ipsec_cert.cert_pem
  key_pem  = tls_private_key.ipsec_key.private_key_pem
  ca_pem   = var.config.project_ca.pem
}
module "ipsec_files" {
  source      = "../../../aa-catalog/catalog/terraform/modules/remote_files"
  name        = "ipsec-${var.office.name}"
  remote_root = module.ipsec_mesh.remote_root
  sudo        = true
  owner       = "root"
  group       = "root"
  connection = {
    host        = var.ssh.host
    user        = var.ssh.user
    private_key = var.ssh.private_key
    timeout     = "5m"
  }
  files = merge(module.ipsec_mesh.files, {
    "scripts/post-config.d/ipsec-nat-accept" = {
      content = local.ipsec_nat_accept
      mode    = "0755"
    }
    "scripts/set-dns-forwarders" = {
      content = local.set_dns_forwarders
      mode    = "0755"
    }
  })
  directories = merge(module.ipsec_mesh.directories, {
    scripts                 = { mode = "0755" }
    "scripts/post-config.d" = { mode = "0755" }
  })
  remote_commands = [
    "/config/scripts/post-config.d/ipsec-nat-accept",
    "/config/scripts/set-dns-forwarders",
    "ipsec restart",
  ]
}
