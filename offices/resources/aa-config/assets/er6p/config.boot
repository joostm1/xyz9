firewall {
    all-ping enable
    broadcast-ping disable
    group {
        address-group dbt_allowed {
            address 52.3.77.232
            address 3.214.191.130
            address 34.233.79.135
        }
    }
    ipv6-name WANV6_IN {
        default-action drop
        rule 10 {
            action accept
            state {
                established enable
                related enable
            }
        }
        rule 20 {
            action drop
            state {
                invalid enable
            }
        }
        rule 22 {
            action accept
            description "Allow SSH in"
            destination {
                port 22
            }
            protocol tcp
            state {
                new enable
            }
        }
        rule 25 {
            action accept
            description SMTP
            destination {
                port 25
            }
            protocol tcp
            state {
                new enable
            }
        }
        rule 30 {
            action accept
            icmpv6 {
            }
            protocol ipv6-icmp
        }
        rule 40 {
            action accept
            description DHCP
            destination {
                port 546
            }
            protocol udp
            source {
                port 547
            }
        }
        rule 143 {
            action accept
            description IMAP
            destination {
                port 143
            }
            protocol tcp
            state {
                new enable
            }
        }
        rule 443 {
            action accept
            description https
            destination {
                port 443
            }
            protocol tcp
        }
        rule 465 {
            action accept
            description ESMTP
            destination {
                port 465
            }
            protocol tcp
            state {
                new enable
            }
        }
        rule 587 {
            action accept
            description ESMTP-TLS
            destination {
                port 587
            }
            protocol tcp
            state {
                new enable
            }
        }
        rule 993 {
            action accept
            description IMAP4
            destination {
                port 993
            }
            protocol tcp
            state {
                new enable
            }
        }
        rule 4500 {
            action accept
            description IPSEC_NAT
            destination {
                port 4500
            }
            protocol udp
            state {
                new enable
            }
        }
        rule 5432 {
            action accept
            description postgresql
            destination {
                port 5432
            }
            protocol tcp
            state {
                new enable
            }
        }
        rule 8080 {
            action accept
            description "unifi device"
            destination {
                port 8080
            }
            protocol tcp
            state {
                new enable
            }
        }
    }
    ipv6-name WANV6_LOCAL {
        default-action drop
        rule 10 {
            action accept
            state {
                established enable
                related enable
            }
        }
        rule 20 {
            action drop
            state {
                invalid enable
            }
        }
        rule 22 {
            action accept
            description "Allow SSH to router"
            destination {
                port 22
            }
            protocol tcp
            state {
                new enable
            }
        }
        rule 30 {
            action accept
            icmpv6 {
            }
            protocol ipv6-icmp
        }
        rule 40 {
            action accept
            description DHCP
            destination {
                port 546
            }
            protocol udp
            source {
                port 547
            }
        }
    }
    ipv6-receive-redirects disable
    ipv6-src-route disable
    ip-src-route disable
    log-martians enable
    name WAN_IN {
        default-action drop
        description "WAN to LAN"
        rule 10 {
            action accept
            description "Allow established/related"
            state {
                established enable
                related enable
            }
        }
        rule 20 {
            action drop
            description "Drop invalid state"
            state {
                invalid enable
            }
        }
        rule 22 {
            action accept
            description "Allow SSH in"
            destination {
                port 22
            }
            protocol tcp
            state {
                new enable
            }
        }
        rule 25 {
            action accept
            description SMTP
            destination {
                port 25
            }
            protocol tcp
            state {
                new enable
            }
        }
        rule 143 {
            action accept
            description IMAP
            destination {
                port 143
            }
            protocol tcp
            state {
                new enable
            }
        }
        rule 443 {
            action accept
            description web
            destination {
                port 443
            }
            protocol tcp
            state {
                new enable
            }
        }
        rule 465 {
            action accept
            description ESMTP
            destination {
                port 465
            }
            protocol tcp
            state {
                new enable
            }
        }
        rule 587 {
            action accept
            description ESMTP-TLS
            destination {
                port 587
            }
            protocol tcp
            state {
                new enable
            }
        }
        rule 993 {
            action accept
            description IMAP4
            destination {
                port 993
            }
            protocol tcp
            state {
                new enable
            }
        }
        rule 4500 {
            action accept
            description IPSEC_NAT
            destination {
                port 4500
            }
            protocol udp
            state {
                new enable
            }
        }
        rule 5432 {
            action accept
            description postgresql
            destination {
                port 5432
            }
            protocol tcp
            source {
                group {
                    address-group dbt_allowed
                }
            }
            state {
                new enable
            }
        }
        rule 8080 {
            action accept
            description "unifi device"
            destination {
                port 8080
            }
            protocol tcp
            state {
                new enable
            }
        }
    }
    name WAN_LOCAL {
        default-action drop
        description "WAN to router"
        rule 10 {
            action accept
            description "Allow established/related"
            state {
                established enable
                related enable
            }
        }
        rule 11 {
            action accept
            description "Allow echo"
            icmp {
                type 8
            }
            protocol icmp
        }
        rule 20 {
            action drop
            description "Drop invalid state"
            state {
                invalid enable
            }
        }
        rule 22 {
            action accept
            description "Allow SSH to Edgerouter"
            destination {
                port 22
            }
            protocol tcp
            state {
                new enable
            }
        }
        rule 30 {
            action accept
            description ike
            destination {
                port 500,4500
            }
            log disable
            protocol udp
        }
        rule 40 {
            action accept
            description esp
            log disable
            protocol esp
        }
        rule 67 {
            action accept
            description "Allow DHCP"
            destination {
                port 68
            }
            protocol udp
            source {
                port 67
            }
        }
    }
    receive-redirects disable
    send-redirects enable
    source-validation disable
    syn-cookies enable
}
interfaces {
    ethernet eth0 {
        description wan
        duplex auto
        mtu 1512
        speed auto
        vif 6 {
            description "kpn wan"
            mtu 1508
            pppoe 0 {
                default-route auto
                dhcpv6-pd {
                    pd 0 {
                        interface eth1 {
                            host-address ::1
                            prefix-id :1
                            service slaac
                        }
                        prefix-length /48
                    }
                    prefix-only
                    rapid-commit enable
                }
                firewall {
                    in {
                        ipv6-name WANV6_IN
                        name WAN_IN
                    }
                    local {
                        ipv6-name WANV6_LOCAL
                        name WAN_LOCAL
                    }
                }
                ipv6 {
                    address {
                        autoconf
                    }
                    dup-addr-detect-transmits 1
                    enable {
                    }
                }
                mtu 1500
                name-server auto
                password "****************"
                user-id 18-e8-29-43-ae-89@internet
            }
        }
    }
    ethernet eth1 {
        address 172.17.114.4/24
        address fd17:114::4/64
        description lan
        duplex auto
        ipv6 {
            dup-addr-detect-transmits 1
            router-advert {
                cur-hop-limit 64
                link-mtu 0
                managed-flag false
                max-interval 600
                name-server fd17:114::4
                other-config-flag false
                prefix ::/64 {
                    autonomous-flag true
                    on-link-flag true
                    valid-lifetime 2592000
                }
                reachable-time 0
                retrans-timer 0
                send-advert true
            }
        }
        speed auto
    }
    ethernet eth2 {
        description eth2
        duplex auto
        speed auto
    }
    ethernet eth3 {
        description eth3
        duplex auto
        speed auto
    }
    ethernet eth4 {
        description eth4
        duplex auto
        speed auto
    }
    ethernet eth5 {
        description sfp
        duplex auto
        speed auto
    }
    loopback lo {
    }
}
port-forward {
    auto-firewall disable
    hairpin-nat enable
    lan-interface eth1
    rule 25 {
        description SMTP
        forward-to {
            address 172.17.114.99
            port 25
        }
        original-port 25
        protocol tcp
    }
    rule 143 {
        description IMAP
        forward-to {
            address 172.17.114.99
            port 143
        }
        original-port 143
        protocol tcp
    }
    rule 443 {
        description web
        forward-to {
            address 172.17.114.99
            port 443
        }
        original-port 443
        protocol tcp
    }
    rule 465 {
        description ESMTP
        forward-to {
            address 172.17.114.99
            port 465
        }
        original-port 465
        protocol tcp
    }
    rule 587 {
        description ESMTP-TLS
        forward-to {
            address 172.17.114.99
            port 587
        }
        original-port 587
        protocol tcp
    }
    rule 993 {
        description IMAP4
        forward-to {
            address 172.17.114.99
            port 993
        }
        original-port 993
        protocol tcp
    }
    rule 5432 {
        description postgresql
        forward-to {
            address 172.17.114.99
            port 5432
        }
        original-port 5432
        protocol tcp
    }
    rule 8080 {
        description unifi-device
        forward-to {
            address 172.17.114.99
            port 8080
        }
        original-port 8080
        protocol tcp
    }
    wan-interface pppoe0
}
protocols {
    static {
        interface-route6 ::/0 {
            next-hop-interface pppoe0 {
            }
        }
    }
}
service {
    dhcp-server {
        disabled false
        hostfile-update disable
        shared-network-name br0 {
            authoritative disable
            subnet 172.17.114.0/24 {
                default-router 172.17.114.4
                dns-server 172.17.114.4
                domain-name xyz9.net
                lease 7200
                start 172.17.114.10 {
                    stop 172.17.114.100
                }
                subnet-parameters "option subnet-mask 255.255.255.0;"
                subnet-parameters "on commit { set clip = binary-to-ascii(10, 8, &quot;.&quot;, leased-address);  set clnm = pick-first-value(option fqdn.hostname, option host-name, &quot;UNKNOWN&quot;);           set clhw = binary-to-ascii(16, 8, &quot;:&quot;, substring(hardware, 1, 6));            execute(&quot;/config/dhcpevent&quot;, &quot;commit&quot;, clip, clhw, clnm);         }"
                unifi-controller 172.17.114.27
            }
        }
        static-arp disable
        use-dnsmasq disable
    }
    dns {
        forwarding {
            cache-size 3000
            listen-on eth1
            name-server 8.8.8.8
            name-server 2001:4860:4860::8888
        }
    }
    mdns {
    }
    nat {
        rule 5000 {
            outbound-interface pppoe0
            protocol all
            type masquerade
        }
    }
    ssh {
        disable-password-authentication
        port 22
        protocol-version v2
    }
    ubnt-discover {
        disable
    }
    unms {
        disable
    }
}
system {
    analytics-handler {
        send-analytics-report true
    }
    config-management {
        commit-revisions 20
    }
    conntrack {
        expect-table-size 2048
        hash-size 32768
        table-size 262144
    }
    crash-handler {
        send-crash-report true
    }
    domain-search {
        domain xyz9.net
    }
    host-name egx
    login {
        user joost {
            authentication {
                encrypted-password $5$iMqD63ALyODO8Ec/$pKf3oLEm11rbT6z3CzQ3CUhDWWpBMRHyOHfC0Bb5qi3
                public-keys joost@xyz9 {
                    key AAAAB3NzaC1yc2EAAAABJQAAAQEApwUHXHOvdNqfZr+b/IG3bmHJZv9vGmcOnHXuXDxufHlt5LTbFQS9DRpTLieI0WWrmSsZRSUwUo1JFx0tLZ813Q3Dd91Xh2zbm64wGuJ3aYLTh6ESZ5UiSfI34qJ9RCPn4tu3k5iXIypSpdFLzUKf2azogRtfmQrhDNt4wrB/K6pLzFFeo6mx9xYMd5gvvMP+qpPUcjdIQcOkydXsVoyu+9m1jp9H/yix6ZBU2y/3tQovgXiXYI+jVj7bZVxwNjNm3adu65nnzBOgiiOle/k3kYi4iNZz6E3yNEllWetnGl7+4zWQD0wxVL+XxzgtypXsL6DKUseBCpofSzbQHuPodQ==
                    type ssh-rsa
                }
            }
            level admin
        }
        user root {
            authentication {
                encrypted-password $5$ShS553d0ntIk7eNA$U.fVwtmhUB2RFkd0bCxQO1PK8Yx4chzIv7kBqKQUaZ0
                plaintext-password ""
            }
            level admin
        }
    }
    name-server 127.0.0.1
    name-server 8.8.8.8
    name-server 2001:4860:4860::8888
    name-server 2001:4860:4860::8844
    name-server 8.8.4.4
    ntp {
        server 0.pool.ntp.org {
        }
        server 1.pool.ntp.org {
        }
        server 2.pool.ntp.org {
        }
        server 3.pool.ntp.org {
        }
    }
    offload {
        hwnat disable
        ipsec enable
        ipv4 {
            bonding enable
            forwarding enable
            gre enable
            pppoe enable
            vlan enable
        }
        ipv6 {
            forwarding enable
            pppoe enable
            vlan disable
        }
    }
    package {
        repository stretch {
            components "main contrib non-free"
            distribution stretch
            password "****************"
            url http://archive.debian.org/debian
            username ""
        }
    }
    syslog {
        file dhcpd.log {
            facility local7 {
                level err
            }
        }
        global {
            facility all {
                level notice
            }
            facility protocols {
                level debug
            }
        }
    }
    time-zone Europe/Amsterdam
}
vpn {
    ipsec {
        allow-access-to-local-interface enable
        auto-firewall-nat-exclude enable
        include-ipsec-conf /config/ipsec.conf
        include-ipsec-secrets /config/ipsec.secrets
        ipsec-interfaces {
            interface pppoe0
        }
    }
}


/* Warning: Do not remove the following line. */
/* === vyatta-config-version: "config-management@1:conntrack@1:cron@1:dhcp-relay@1:dhcp-server@4:firewall@5:ipsec@5:nat@3:qos@1:quagga@2:suspend@1:system@5:ubnt-l2tp@1:ubnt-pptp@1:ubnt-udapi-server@1:ubnt-unms@2:ubnt-util@1:vrrp@1:vyatta-netflow@1:webgui@1:webproxy@1:zone-policy@1" === */
/* Release version: v3.0.0.5842788.250718.1103 */
