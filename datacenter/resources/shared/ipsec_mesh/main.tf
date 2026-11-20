variable "me" {
  type        = any
  description = "This node from mesh_members.members"
}
variable "members" {
  type        = any
  description = "Full mesh member map from mesh_members.members"
}
variable "cert_pem" {
  type        = string
  description = "Leaf certificate PEM for this node"
  sensitive   = true
}
variable "key_pem" {
  type        = string
  description = "Leaf private key PEM for this node"
  sensitive   = true
}
variable "ca_pem" {
  type        = string
  description = "Project CA PEM (may be a chain)"
  sensitive   = true
}
locals {
  peer_names = sort(setsubtract(keys(var.members), [var.me.name]))
  cert_abs   = "${var.me.paths.remote_root}/${var.me.paths.cert}"
  key_abs    = "${var.me.paths.remote_root}/${var.me.paths.key}"
  # strongswan loads CAs from separate files, not a concatenated chain
  ca_chain     = compact([for s in split("-----END", var.ca_pem) : trimspace(replace(s, "/(\\s*-----.+)|(.+-----\\s*)/", ""))])
  ca_chain_rel = [for idx, _ in local.ca_chain : "${var.me.paths.ca_dir}/ca_chain_${idx}.pem"]
  ca_chain_files = {
    for idx, cert in local.ca_chain : local.ca_chain_rel[idx] => {
      content = format("%s\n%s\n%s\n", "-----BEGIN CERTIFICATE-----", cert, "-----END CERTIFICATE-----")
      mode    = "0644"
    }
  }
  # One CHILD_SA per family. Mixed leftsubnet v4+v6 breaks IPv4 on EdgeOS 4.9
  # (old egx snapshot kept leftsubnet IPv4-only; see ipsec.conf.tftpl).
  ts = {
    for name, m in var.members : name => {
      ipv4 = [for s in m.subnets : s if !strcontains(s, ":")]
      ipv6 = [for s in m.subnets : s if strcontains(s, ":")]
    }
  }
  ipsec_conf = templatefile("${path.module}/ipsec.conf.tftpl", {
    me         = var.me
    members    = var.members
    peer_names = local.peer_names
    ts         = local.ts
    families   = ["ipv4", "ipv6"]
    cert_abs   = local.cert_abs
    ca_abs     = [for rel in local.ca_chain_rel : "${var.me.paths.remote_root}/${rel}"]
  })
  files = merge(
    {
      (var.me.paths.conf) = {
        content = local.ipsec_conf
        mode    = "0644"
      }
      (var.me.paths.secrets) = {
        content = ": RSA \"${local.key_abs}\"\n"
        mode    = "0600"
      }
      (var.me.paths.cert) = {
        content = var.cert_pem
        mode    = "0644"
      }
      (var.me.paths.key) = {
        content = var.key_pem
        mode    = "0600"
      }
    },
    local.ca_chain_files
  )
  directories = var.me.kind == "hub" ? {
    "ipsec.d"         = { mode = "0755" }
    "ipsec.d/certs"   = { mode = "0755" }
    "ipsec.d/private" = { mode = "0700" }
    "ipsec.d/cacerts" = { mode = "0755" }
    } : {
    "auth"            = { mode = "0700" }
    "ipsec.d"         = { mode = "0755" }
    "ipsec.d/cacerts" = { mode = "0755" }
  }
}
output "files" {
  value       = local.files
  sensitive   = true
  description = "remote_files map: relative path => { content, mode }"
}
output "directories" {
  value       = local.directories
  description = "remote_files directories map: relative path => { mode }"
}
output "remote_root" {
  value       = var.me.paths.remote_root
  description = "Install root for this node's IPsec files"
}
