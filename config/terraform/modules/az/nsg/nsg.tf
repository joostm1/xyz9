variable "name" {
  type = string
}

variable "rg_name" {
  type = string
}

variable "rg_location" {
  type = string
}

variable "subnet_id" {
  type = string
}

variable "nsg_rules" {
  type = map(object({
    priority                     = number
    direction                    = optional(string, "Inbound")
    access                       = optional(string, "Allow")
    protocol                     = string
    source_port_range            = optional(string)
    source_port_ranges           = optional(set(string))
    destination_port_range       = optional(string)
    destination_port_ranges      = optional(set(string))
    source_address_prefix        = optional(string)
    source_address_prefixes      = optional(set(string))
    destination_address_prefix   = optional(string)
    destination_address_prefixes = optional(set(string))
  }))
}


resource "azurerm_network_security_group" "this" {
  location            = var.rg_location
  resource_group_name = var.rg_name
  name                = var.name
}

resource "azurerm_subnet_network_security_group_association" "this" {
  subnet_id                 = var.subnet_id
  network_security_group_id = azurerm_network_security_group.this.id
}

resource "azurerm_network_security_rule" "this" {
  for_each = {
    for key, value in var.nsg_rules : key => value
  }
  name      = each.key
  priority  = each.value.priority
  direction = each.value.direction
  access    = each.value.access
  protocol  = title(each.value.protocol)

  source_port_range  = each.value.source_port_range == null && each.value.source_port_ranges == null ? "*" : each.value.source_port_range
  source_port_ranges = each.value.source_port_ranges

  destination_port_range  = each.value.destination_port_range
  destination_port_ranges = each.value.destination_port_ranges

  source_address_prefix   = each.value.source_address_prefix == null && each.value.source_address_prefixes == null ? "*" : each.value.source_address_prefix
  source_address_prefixes = each.value.source_address_prefixes

  destination_address_prefix   = each.value.destination_address_prefix == null && each.value.destination_address_prefixes == null ? "*" : each.value.destination_address_prefix
  destination_address_prefixes = each.value.destination_address_prefixes

  resource_group_name         = var.rg_name
  network_security_group_name = azurerm_network_security_group.this.name
}
