output "config" {
  value = {
    spoke = {
      infra_rg = azurerm_resource_group.spoke_infra_rg
      rg       = azurerm_resource_group.spoke_rg
      vnet = {
        (azurerm_virtual_network.spoke_vnet.name) = {
          id            = azurerm_virtual_network.spoke_vnet.id
          address_space = azurerm_virtual_network.spoke_vnet.address_space
          subnets = {
            (azurerm_subnet.spoke_subnet.name) = {
              id               = azurerm_subnet.spoke_subnet.id
              address_prefixes = azurerm_subnet.spoke_subnet.address_prefixes
            }
          }
        }
      }
    }
    hub = var.hub.config
  }
}
