data "azuread_user" "owner" {
  user_principal_name = var.spoke.project.owner
}
data "azurerm_subscription" "current" {}
# Create the `<spoke>-owner` application and store its PKCS#12 in `kv-xyz9-azhubs` for the spoke azurerm provider
resource "tls_private_key" "client" {
  algorithm = "RSA"
  rsa_bits  = 2048
}
resource "tls_self_signed_cert" "client" {
  private_key_pem       = tls_private_key.client.private_key_pem
  validity_period_hours = 87600
  allowed_uses          = ["client_auth", "digital_signature", "key_encipherment"]
  subject {
    common_name  = "${var.spoke.name}-owner.${var.org.about.dns_domain}"
    organization = var.org.about.x509.org
  }
}
resource "azuread_application" "client" {
  display_name = "${var.spoke.name}-owner"
  owners       = [data.azuread_user.owner.object_id]
}
resource "azuread_service_principal" "client" {
  client_id = azuread_application.client.client_id
  owners    = [data.azuread_user.owner.object_id]
}
resource "azuread_application_certificate" "client" {
  application_id = azuread_application.client.id
  type           = "AsymmetricX509Cert"
  value          = tls_self_signed_cert.client.cert_pem
}
resource "azuread_group_member" "client" {
  group_object_id  = var.spoke.owner_group_object_id
  member_object_id = azuread_service_principal.client.object_id
}
data "external" "client_p12" {
  program = ["python3", "${path.module}/../../aa-foundation/pkcs12.py"]
  query = {
    cert_pem = tls_self_signed_cert.client.cert_pem
    key_pem  = tls_private_key.client.private_key_pem_pkcs8
  }
}
resource "azurerm_key_vault_secret" "client_p12" {
  name         = "${var.spoke.name}-owner-p12"
  value        = data.external.client_p12.result.p12_b64
  key_vault_id = var.project.vault.id
  content_type = "application/x-pkcs12"
}
# Grant `<spoke>-owner` Owner on the azhubs subscription so spoke roots can create resource groups and role assignments
resource "azurerm_role_assignment" "client_subscription" {
  scope                = "/subscriptions/${var.project.azure.subscription_id}"
  role_definition_name = "Owner"
  principal_id         = azuread_service_principal.client.object_id
  principal_type       = "ServicePrincipal"
}
# rg for the spoke vnet to land
resource "azurerm_resource_group" "spoke_infra_rg" {
  name     = "rg-${var.project.name}-${var.hub.name}-${var.spoke.name}-spoke"
  location = var.hub.config.rg.location
}
resource "azurerm_role_assignment" "spoke_rg_reader" {
  scope                = azurerm_resource_group.spoke_infra_rg.id
  role_definition_name = "Reader"
  principal_id         = var.spoke.owner_group_object_id
}
resource "azurerm_resource_group" "spoke_rg" {
  name     = "rg-${var.spoke.name}"
  location = var.hub.config.rg.location
}
resource "azurerm_role_assignment" "spoke_rg_owner" {
  scope                = azurerm_resource_group.spoke_rg.id
  role_definition_name = "Owner"
  principal_id         = var.spoke.owner_group_object_id
}
resource "azurerm_route_table" "spoke_rt" {
  name                = "rt-${var.spoke.name}-zone"
  resource_group_name = azurerm_resource_group.spoke_infra_rg.name
  location            = azurerm_resource_group.spoke_infra_rg.location
  route {
    name                   = "default4"
    address_prefix         = "0.0.0.0/0"
    next_hop_type          = "VirtualAppliance"
    next_hop_in_ip_address = var.hub.config.nva.addresses.private.ipv4
  }
  route {
    name                   = "default6"
    address_prefix         = "::/0"
    next_hop_type          = "VirtualAppliance"
    next_hop_in_ip_address = var.hub.config.nva.addresses.private.ipv6
  }
}
resource "azurerm_virtual_network" "spoke_vnet" {
  name                = "vn1"
  location            = azurerm_resource_group.spoke_infra_rg.location
  resource_group_name = azurerm_resource_group.spoke_infra_rg.name
  address_space       = [for space in var.hub.config.spokes_address_space : cidrsubnet(space, 4, 0)]
  # dns directs to hub for observability
  dns_servers = [
    var.hub.config.nva.addresses.private.ipv4,
    var.hub.config.nva.addresses.private.ipv6
  ]
}
resource "azurerm_subnet" "spoke_subnet" {
  name                            = "sn1"
  resource_group_name             = azurerm_resource_group.spoke_infra_rg.name
  virtual_network_name            = azurerm_virtual_network.spoke_vnet.name
  address_prefixes                = azurerm_virtual_network.spoke_vnet.address_space
  default_outbound_access_enabled = false
}
resource "azurerm_private_dns_zone_virtual_network_link" "spoke_vnet_dns_link" {
  for_each             = toset(var.project.azure.private_dns_zones)
  name                 = "${var.spoke.name}-${each.key}"
  private_dns_zone_id  = "${var.project.rg.id}/providers/Microsoft.Network/privateDnsZones/${each.key}"
  virtual_network_id   = azurerm_virtual_network.spoke_vnet.id
  registration_enabled = false
}
module "nsg" {
  source      = "../../../catalog/terraform/modules/az/nsg"
  name        = "nsg"
  rg_name     = azurerm_resource_group.spoke_infra_rg.name
  rg_location = azurerm_resource_group.spoke_infra_rg.location
  subnet_id   = azurerm_subnet.spoke_subnet.id
  nsg_rules = {
    allow_all_in = {
      priority               = 400
      protocol               = "*"
      destination_port_range = "*"
      access                 = "Allow"
      direction              = "Inbound"
      source_address_prefix  = "*"
    }
    allow_all_out = {
      priority               = 500
      protocol               = "*"
      destination_port_range = "*"
      access                 = "Allow"
      direction              = "Outbound"
      source_address_prefix  = "*"
    }
  }
}
resource "azurerm_subnet_route_table_association" "spoke_route_table" {
  subnet_id      = azurerm_subnet.spoke_subnet.id
  route_table_id = azurerm_route_table.spoke_rt.id
}
# allow_forwarded_traffic defaults false; office→NVA→spoke still works (docs say it shouldn't).
resource "azurerm_virtual_network_peering" "spoke_hub" {
  name                      = "${var.project.name}-${var.spoke.name}-${var.hub.name}"
  resource_group_name       = azurerm_resource_group.spoke_infra_rg.name
  virtual_network_name      = azurerm_virtual_network.spoke_vnet.name
  remote_virtual_network_id = var.hub.config.vnet.id
}
resource "azurerm_virtual_network_peering" "hub_spoke" {
  name                      = "${var.project.name}-${var.hub.name}-${var.spoke.name}"
  resource_group_name       = var.hub.config.rg.name
  virtual_network_name      = var.hub.config.vnet.name
  remote_virtual_network_id = azurerm_virtual_network.spoke_vnet.id
}
