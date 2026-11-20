variable "hub" {
  type = object({
    name   = string
    config = any
  })
  description = "the configuration for the location"
}
variable "config" {
  type = object({
    org        = any
    project    = any
    project_ca = any
  })
}
variable "members" {
  type        = any
  description = "IPsec mesh members from resources/shared/mesh_members"
}
variable "dc_secrets" {
  type      = map(string)
  sensitive = true
}
locals {
  me = var.members[var.hub.name]
  # hubs + spokes + offices; BIND defaults recursion to localnets without this
  mesh_dns_acl = concat(
    ["127.0.0.1", "::1"],
    sort(distinct(flatten([for m in var.members : m.subnets])))
  )
  # https://www.youtube.com/watch?v=40SnEd1RWUU
  cloud_init_config = {
    package_upgrade = true
    packages = [
      "strongswan",
      "libcharon-extra-plugins",
      "strongswan-pki",
      "iptables-persistent",
      "bind9",
      "ipcalc"
    ],
    swap = {
      filename = "/swapfile"
      size     = "4G"
    }
    runcmd = [
      "sysctl -p",
      # name resolution - alias of localhost
      "sed -i -e \"s/^\\(127.0.0.1 localhost\\)/\\1 $(cat /etc/hostname)/\" /etc/hosts",
      # masquerade all outbound traffic from spokes as originating from our eth0
      "iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE",
      "ip6tables -t nat -A POSTROUTING -o eth0 -j MASQUERADE",
      # https://docs.strongswan.org/docs/latest/howtos/forwarding.html#_general_nat_problems
      # most briljant, insightful & helpful statement I've ever seen
      "iptables -t nat -I POSTROUTING -m policy --pol ipsec --dir out -j ACCEPT",
      "ip6tables -t nat -I POSTROUTING -m policy --pol ipsec --dir out -j ACCEPT",
      # mss clamping for ipsec traffic - attach a maximum segment size request to all outbound to prevent fragmentation due to [ipsec] overhead
      "iptables -t mangle -A FORWARD -m policy --pol ipsec --dir out -p tcp -m tcp --tcp-flags SYN,RST SYN -m tcpmss --mss 1361:1536 -j TCPMSS --set-mss 1360",
      "ip6tables -t mangle -A FORWARD -m policy --pol ipsec --dir out -p tcp -m tcp --tcp-flags SYN,RST SYN -m tcpmss --mss 1361:1536 -j TCPMSS --set-mss 1360",
      "iptables-save > /etc/iptables/rules.v4",
      "ip6tables-save > /etc/iptables/rules.v6",
      "systemctl enable netfilter-persistent.service",
      "systemctl start netfilter-persistent.service",
      "systemctl enable bind9.service",
      "systemctl start bind9.service",
      "resolvectl dns eth0 127.0.0.1 ::1",
      "resolvectl domain eth0 ${var.config.org.about.dns_domain}"
    ],
    write_files = [
      {
        path        = "/etc/sysctl.conf"
        owner       = "root:root"
        defer       = true
        content     = <<-EOT
            net.ipv4.ip_forward = 1
            net.ipv6.conf.all.forwarding = 1
            net.ipv4.ip_no_pmtu_disc=1
          EOT
        permissions = "0644"
      }
    ]
  }
}
