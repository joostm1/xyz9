variable "dns_domain" {
  type        = string
  description = "Org DNS domain, e.g. xyz9.net"
}
variable "hubs" {
  type        = any
  description = "datacenter hubs keyed by hub code"
}
variable "offices" {
  type        = any
  default     = {}
  description = "Office sites keyed by office code"
}
locals {
  hubs = {
    for name, loc in var.hubs : name => {
      name       = name
      kind       = "hub"
      id         = "r${name}.${var.dns_domain}"
      local_ike  = "r${name}-private.${var.dns_domain}"
      remote_ike = "r${name}-ipv4.${var.dns_domain}"
      subnets    = flatten([loc.address_space, loc.spokes_address_space])
      cert_name  = "r${name}"
      paths = {
        remote_root = "/etc"
        conf        = "ipsec.conf"
        secrets     = "ipsec.secrets"
        cert        = "ipsec.d/certs/r${name}.pem"
        key         = "ipsec.d/private/r${name}.pem"
        ca_dir      = "ipsec.d/cacerts"
      }
    }
  }
  offices = {
    for name, office in var.offices : name => {
      name       = name
      kind       = "office"
      id         = "${office.network.router}.${var.dns_domain}"
      local_ike  = "${office.network.router}.${var.dns_domain}"
      remote_ike = "${office.network.router}-ipv4.${var.dns_domain}"
      subnets    = office.network.address_space
      cert_name  = office.network.router
      paths = {
        remote_root = "/config"
        conf        = "ipsec.conf"
        secrets     = "ipsec.secrets"
        cert        = "auth/${office.network.router}.pem"
        key         = "auth/${office.network.router}-key.pem"
        ca_dir      = "ipsec.d/cacerts"
      }
    }
  }
}
output "members" {
  value       = merge(local.hubs, local.offices)
  description = "IPsec mesh members keyed by location or office code"
}
