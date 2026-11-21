# rg for the spoke vnet to land
resource "azurerm_resource_group" "spoke_infra_rg" {
  name     = "rg-${var.project.name}-${var.hub.name}-${var.spoke.name}-spoke"
  location = var.hub.config.rg.location
}
resource "azurerm_role_assignment" "spoke_rg_reader" {
  scope                = azurerm_resource_group.spoke_infra_rg.id
  role_definition_name = "Reader"
  principal_id         = var.spoke.project.projects.projects.identity.owner.group_object_id
}
resource "azurerm_resource_group" "spoke_rg" {
  name     = "rg-${var.spoke.name}"
  location = var.hub.config.rg.location
}
resource "azurerm_role_assignment" "spoke_rg_owner" {
  scope                = azurerm_resource_group.spoke_rg.id
  role_definition_name = "Owner"
  principal_id         = var.spoke.project.projects.projects.identity.owner.group_object_id
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
  source      = "../../../aa-catalog/catalog/terraform/modules/az/nsg"
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
