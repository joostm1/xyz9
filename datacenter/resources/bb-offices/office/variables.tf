variable "office" {
  type = object({
    name   = string
    config = any
  })
}
variable "members" {
  type = any
}
variable "hub_dns_ipv4" {
  type        = list(string)
  description = "Hub NVA private IPv4 resolvers, tried before IPv6 hubs and 8.8.8.8."
}
variable "hub_dns_ipv6" {
  type        = list(string)
  description = "Hub NVA private IPv6 resolvers; quoted for EdgeOS so ':' is not a path."
}
variable "ssh" {
  type = object({
    host        = string
    user        = string
    private_key = string
  })
  sensitive = true
}
variable "config" {
  type = object({
    org        = any
    project    = any
    project_ca = any
  })
}
locals {
  me     = var.members[var.office.name]
  router = var.office.config.network.router
  domain = var.config.org.about.dns_domain
  # https://docs.strongswan.org/docs/latest/howtos/forwarding.html#_general_nat_problems
  # most briljant, insightful & helpful statement I've ever seen
  # EdgeOS auto-firewall-nat-exclude does not cover include-ipsec-conf SAs.
  ipsec_nat_accept = <<-EOT
    #!/bin/sh
    ensure() {
      ipt=$1
      table=$2
      shift 2
      $ipt -t "$table" -C "$@" 2>/dev/null && return 0
      $ipt -t "$table" -I "$@"
    }
    ensure iptables nat POSTROUTING -m policy --pol ipsec --dir out -j ACCEPT
    ensure ip6tables nat POSTROUTING -m policy --pol ipsec --dir out -j ACCEPT
    ensure iptables mangle FORWARD -m policy --pol ipsec --dir out -p tcp -m tcp --tcp-flags SYN,RST SYN -m tcpmss --mss 1361:1536 -j TCPMSS --set-mss 1360
    ensure ip6tables mangle FORWARD -m policy --pol ipsec --dir out -p tcp -m tcp --tcp-flags SYN,RST SYN -m tcpmss --mss 1361:1536 -j TCPMSS --set-mss 1360
  EOT
  # Hubs first (v4 then v6), Google last. Blob tfstate has no PE; hub bind returns the public CNAME.
  set_dns_forwarders = join("\n", concat(
    [
      "#!/bin/vbash",
      "set -e",
      "WRAPPER=/opt/vyatta/sbin/vyatta-cfg-cmd-wrapper",
      "$WRAPPER begin",
      "$WRAPPER delete service dns forwarding name-server",
      "$WRAPPER delete service dns forwarding options",
    ],
    [for ip in var.hub_dns_ipv4 : "$WRAPPER set service dns forwarding name-server ${ip}"],
    [for ip in var.hub_dns_ipv6 : "$WRAPPER set service dns forwarding name-server '${ip}'"],
    [
      "$WRAPPER set service dns forwarding name-server 8.8.8.8",
      "$WRAPPER set service dns forwarding name-server '2001:4860:4860::8888'",
      "$WRAPPER set service dns forwarding options strict-order",
      "$WRAPPER commit",
      "$WRAPPER save",
      "$WRAPPER end",
    ]
  ))
}
