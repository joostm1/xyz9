# hub/main.tf - create a hub in an azure region
resource "azurerm_resource_group" "rghub" {
  location = var.config.project.locations[var.hub.name].region
  name     = "rg-${var.config.project.name}-${var.hub.name}"
  tags = {
    deployment_date = formatdate("YYYY-MM-DD", timestamp())
  }
  lifecycle {
    ignore_changes = [tags]
  }
}
# functional role assignments on the rg
module "rg_role_assignments" {
  source           = "../../../catalog/terraform/modules/az/role_assignments"
  entra_groups     = var.config.project.groups
  assignment_scope = azurerm_resource_group.rghub.id
  role_assignments = {
    project = {
      admin = {
        "Owner" = true
      }
      engineer = {
        "Contributor" = true
      }
      regions = {
        apc = {
          manager = {
            "Owner" = true
          }
        }
      }
    }
  }
}
# public ipv6 prefix for this hub ~ 4 bits = 16 addresses
resource "azurerm_public_ip_prefix" "ipv6pfx" {
  name                = "px6"
  location            = azurerm_resource_group.rghub.location
  resource_group_name = azurerm_resource_group.rghub.name
  prefix_length       = 124
  ip_version          = "IPv6"
}
# public ipv6 address for the NVA in the ipv6pfx space
resource "azurerm_public_ip" "nvapip6" {
  name                 = "nvapip6"
  location             = azurerm_resource_group.rghub.location
  resource_group_name  = azurerm_resource_group.rghub.name
  sku                  = "Standard"
  allocation_method    = "Static"
  ip_version           = "IPv6"
  ddos_protection_mode = "Disabled"
  public_ip_prefix_id  = azurerm_public_ip_prefix.ipv6pfx.id
}
# public ipv4 address for the NVA, no $prefix because of the "less than an Altairian dollar" promise
resource "azurerm_public_ip" "nvapip4" {
  name                 = "nvapip4"
  location             = azurerm_resource_group.rghub.location
  resource_group_name  = azurerm_resource_group.rghub.name
  sku                  = "Standard"
  allocation_method    = "Static"
  ip_version           = "IPv4"
  ddos_protection_mode = "Disabled"
}
# hub vnet
resource "azurerm_virtual_network" "vnet" {
  name                = "vn1"
  location            = azurerm_resource_group.rghub.location
  resource_group_name = azurerm_resource_group.rghub.name
  address_space       = var.hub.config.address_space
}
resource "azurerm_subnet" "sn1" {
  address_prefixes                              = [for space in var.hub.config.address_space : cidrsubnet(space, 4, 0)]
  name                                          = "sn1"
  resource_group_name                           = azurerm_resource_group.rghub.name
  virtual_network_name                          = azurerm_virtual_network.vnet.name
  default_outbound_access_enabled               = false
  private_link_service_network_policies_enabled = false
}
module "nsg_subnet_sn1" {
  source      = "../../../catalog/terraform/modules/az/nsg"
  name        = "nsg"
  rg_name     = azurerm_resource_group.rghub.name
  rg_location = azurerm_resource_group.rghub.location
  subnet_id   = azurerm_subnet.sn1.id
  nsg_rules = {
    ssh = {
      priority                = 300
      protocol                = "tcp"
      destination_port_ranges = ["22"]
      source_address_prefix   = "Internet"
      direction               = "Inbound"
    }
    ipsec = {
      priority                = 301
      protocol                = "udp"
      destination_port_ranges = ["500", "4500"]
      source_address_prefix   = "Internet"
      direction               = "Inbound"
    }
    spoke_traffic = {
      protocol               = "*"
      destination_port_range = "*"
      priority               = 500
      source_address_prefix  = "VirtualNetwork"
      direction              = "Inbound"
    }
    icmp_echo = {
      priority               = 969
      protocol               = "icmp" # icmp here is icmpv4, no icmpv6. Lead the way azure! https://learn.microsoft.com/en-us/azure/virtual-network/ip-services/ipv6-overview#limitations
      destination_port_range = "*"    # required although ICMP doesn't have ports!?: SecurityRuleParametersMissingForPortRanges: Required security rule parameters are missing for security rule with Id: /subscriptions/98000b13-b691-416e-ad86-ef05d9227b9e/resourceGroups/rg-datacenter-amn1/providers/Microsoft.Network/networkSecurityGroups/nsg/securityRules/icmp_echo. Security rule must specify either DestinationPortRange or DestinationPortRanges.
      source_address_prefix  = "Internet"
      direction              = "Inbound"
    }
  }
}
# private dns links to corp zones
resource "azurerm_private_dns_zone_virtual_network_link" "privatednslink" {
  for_each             = toset(var.config.project.azure.private_dns_zones)
  name                 = "${var.hub.name}-${each.key}"
  private_dns_zone_id  = "${var.config.project.rg.id}/providers/Microsoft.Network/privateDnsZones/${each.key}"
  virtual_network_id   = azurerm_virtual_network.vnet.id
  registration_enabled = false
}
# dns records for the NVA in the hub
resource "cloudflare_dns_record" "nvadns4" {
  zone_id = var.dc_secrets["cloudflare-dns-zoneid"]
  name    = "r${var.hub.name}.${var.config.org.about.dns_domain}"
  content = azurerm_public_ip.nvapip4.ip_address
  type    = "A"
  ttl     = 60
}
resource "cloudflare_dns_record" "nvadns6" {
  zone_id = var.dc_secrets["cloudflare-dns-zoneid"]
  name    = "r${var.hub.name}.${var.config.org.about.dns_domain}"
  content = azurerm_public_ip.nvapip6.ip_address
  type    = "AAAA"
  ttl     = 60
}
resource "cloudflare_dns_record" "nvadns44" {
  zone_id = var.dc_secrets["cloudflare-dns-zoneid"]
  name    = "r${var.hub.name}-ipv4.${var.config.org.about.dns_domain}"
  content = azurerm_public_ip.nvapip4.ip_address
  type    = "A"
  ttl     = 60
}
resource "cloudflare_dns_record" "nvadns66" {
  zone_id = var.dc_secrets["cloudflare-dns-zoneid"]
  name    = "r${var.hub.name}-ipv6.${var.config.org.about.dns_domain}"
  content = azurerm_public_ip.nvapip6.ip_address
  type    = "AAAA"
  ttl     = 60
}
resource "cloudflare_dns_record" "nvadnsi4" {
  zone_id = var.dc_secrets["cloudflare-dns-zoneid"]
  name    = "r${var.hub.name}-private.${var.config.org.about.dns_domain}"
  content = azurerm_network_interface.nvanic1.ip_configuration[0].private_ip_address
  type    = "A"
  ttl     = 60
}
resource "cloudflare_dns_record" "nvadnsi6" {
  zone_id = var.dc_secrets["cloudflare-dns-zoneid"]
  name    = "r${var.hub.name}-private.${var.config.org.about.dns_domain}"
  content = azurerm_network_interface.nvanic1.ip_configuration[1].private_ip_address
  type    = "AAAA"
  ttl     = 60
}
resource "cloudflare_dns_record" "nvadnsi44" {
  zone_id = var.dc_secrets["cloudflare-dns-zoneid"]
  name    = "r${var.hub.name}-private-ipv4.${var.config.org.about.dns_domain}"
  content = azurerm_network_interface.nvanic1.ip_configuration[0].private_ip_address
  type    = "A"
  ttl     = 60
}
resource "cloudflare_dns_record" "nvadnsi66" {
  zone_id = var.dc_secrets["cloudflare-dns-zoneid"]
  name    = "r${var.hub.name}-private-ipv6.${var.config.org.about.dns_domain}"
  content = azurerm_network_interface.nvanic1.ip_configuration[1].private_ip_address
  type    = "AAAA"
  ttl     = 60
}
# nva private addresses
resource "azurerm_network_interface" "nvanic1" {
  name                           = "nvanic1"
  location                       = azurerm_resource_group.rghub.location
  resource_group_name            = azurerm_resource_group.rghub.name
  accelerated_networking_enabled = true
  ip_forwarding_enabled          = true
  ip_configuration {
    name                          = "ipconfigv4"
    subnet_id                     = azurerm_subnet.sn1.id
    private_ip_address_allocation = "Dynamic"
    private_ip_address_version    = "IPv4"
    public_ip_address_id          = azurerm_public_ip.nvapip4.id
    primary                       = true
  }
  ip_configuration {
    name                          = "ipconfigv6"
    subnet_id                     = azurerm_subnet.sn1.id
    private_ip_address_allocation = "Dynamic"
    private_ip_address_version    = "IPv6"
    public_ip_address_id          = azurerm_public_ip.nvapip6.id
    primary                       = false
  }
}
# private key for ipsec
resource "tls_private_key" "nva_ipsec_key" {
  algorithm = "RSA"
  rsa_bits  = 2048
}
# sign request for the nva's cert
resource "tls_cert_request" "nva_ipsec_csr" {
  private_key_pem = tls_private_key.nva_ipsec_key.private_key_pem
  dns_names = [
    "r${var.hub.name}.${var.config.org.about.dns_domain}",
    "r${var.hub.name}-ipv4.${var.config.org.about.dns_domain}",
    "r${var.hub.name}-ipv6.${var.config.org.about.dns_domain}",
    "r${var.hub.name}-private.${var.config.org.about.dns_domain}",
    "r${var.hub.name}-private-ipv4.${var.config.org.about.dns_domain}",
    "r${var.hub.name}-private-ipv6.${var.config.org.about.dns_domain}",
  ]
  subject {
    organization = var.config.org.about.x509.org
    country      = var.config.org.about.x509.ca.country
    common_name  = "r${var.hub.name}.${var.config.org.about.dns_domain}"
  }
}
# cert for ipsec
resource "tls_locally_signed_cert" "nva_ipsec_cert" {
  cert_request_pem      = tls_cert_request.nva_ipsec_csr.cert_request_pem
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
resource "azurerm_key_vault_certificate" "nva_ipsec_cert" {
  name         = "r${var.hub.name}-ipsec-cert"
  key_vault_id = var.config.project.vault.id
  certificate {
    contents = format("%s%s",
      tls_locally_signed_cert.nva_ipsec_cert.cert_pem,
      tls_private_key.nva_ipsec_key.private_key_pem_pkcs8
    )
  }
}
resource "tls_private_key" "nva_ssh_key" {
  algorithm = "RSA"
  rsa_bits  = 2048
}
resource "azurerm_key_vault_secret" "nva_ssh_key" {
  name         = "nva-ssh-key-${var.hub.name}"
  key_vault_id = var.config.project.vault.id
  value        = tls_private_key.nva_ssh_key.private_key_openssh
}
data "cloudinit_config" "nvapost" {
  gzip          = true
  base64_encode = true
  part {
    content_type = "text/cloud-config"
    content      = yamlencode(local.cloud_init_config)
  }
}
resource "azurerm_linux_virtual_machine" "nva" {
  name                            = "r${var.hub.name}"
  resource_group_name             = azurerm_resource_group.rghub.name
  location                        = azurerm_resource_group.rghub.location
  size                            = "Standard_B2ats_v2"
  admin_username                  = var.hub.name
  network_interface_ids           = [azurerm_network_interface.nvanic1.id]
  custom_data                     = data.cloudinit_config.nvapost.rendered
  disable_password_authentication = true
  vtpm_enabled                    = true
  disk_controller_type            = "SCSI"
  identity {
    type = "SystemAssigned"
  }
  admin_ssh_key {
    username   = var.hub.name
    public_key = tls_private_key.nva_ssh_key.public_key_openssh
  }
  os_disk {
    caching                   = "ReadOnly"
    storage_account_type      = "Standard_LRS"
    disk_size_gb              = 32
    name                      = "r${var.hub.name}-osdisk"
    write_accelerator_enabled = false
  }
  source_image_reference {
    publisher = "Canonical"
    offer     = "ubuntu-24_04-lts"
    sku       = "server"
    version   = "latest"
  }
}
module "ipsec_mesh" {
  source   = "../../shared/ipsec_mesh"
  me       = local.me
  members  = var.members
  cert_pem = tls_locally_signed_cert.nva_ipsec_cert.cert_pem
  key_pem  = tls_private_key.nva_ipsec_key.private_key_pem
  ca_pem   = var.config.project_ca.pem
}
module "ipsec_files" {
  source      = "../../../catalog/terraform/modules/remote_files"
  name        = "ipsec-${var.hub.name}"
  remote_root = module.ipsec_mesh.remote_root
  sudo        = true
  owner       = "root"
  group       = "root"
  connection = {
    host        = azurerm_public_ip.nvapip4.ip_address
    user        = var.hub.name
    private_key = tls_private_key.nva_ssh_key.private_key_openssh
    timeout     = "15m"
  }
  files            = module.ipsec_mesh.files
  directories      = module.ipsec_mesh.directories
  triggers_replace = azurerm_linux_virtual_machine.nva.id
  pre_commands = [
    "cloud-init status --wait || { [ $? -eq 2 ] || { cloud-init status --long; exit 1; }; }"
  ]
  remote_commands = ["ipsec restart"]
  depends_on      = [azurerm_linux_virtual_machine.nva]
}
locals {
  named_conf_options = <<-EOT
    acl "mesh" {
      ${join("\n      ", [for c in local.mesh_dns_acl : "${c};"])}
    };
    options {
      directory "/var/cache/bind";
      recursion yes;
      allow-query { mesh; };
      allow-recursion { mesh; };
      allow-query-cache { mesh; };
      listen-on { 127.0.0.1; ${azurerm_network_interface.nvanic1.ip_configuration[0].private_ip_address}; };
      listen-on-v6 { ::1; ${azurerm_network_interface.nvanic1.ip_configuration[1].private_ip_address}; };
      forwarders { 168.63.129.16; };
    };
  EOT
}
module "bind_files" {
  source      = "../../../catalog/terraform/modules/remote_files"
  name        = "bind-${var.hub.name}"
  remote_root = "/etc"
  sudo        = true
  owner       = "root"
  group       = "bind"
  connection = {
    host        = azurerm_public_ip.nvapip4.ip_address
    user        = var.hub.name
    private_key = tls_private_key.nva_ssh_key.private_key_openssh
    timeout     = "15m"
  }
  files = {
    "bind/named.conf.options" = {
      content = local.named_conf_options
      mode    = "0644"
    }
  }
  directories = {
    bind = { mode = "0755" }
  }
  triggers_replace = azurerm_linux_virtual_machine.nva.id
  pre_commands = [
    "cloud-init status --wait || { [ $? -eq 2 ] || { cloud-init status --long; exit 1; }; }"
  ]
  remote_commands = ["named-checkconf", "systemctl reload bind9"]
  depends_on      = [module.ipsec_files]
}
