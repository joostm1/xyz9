output "config" {
  # merge hub static config with runtime addresses for successors
  value = merge(var.hub.config, {
    rg = {
      name     = azurerm_resource_group.rghub.name
      id       = azurerm_resource_group.rghub.id
      location = azurerm_resource_group.rghub.location
    }
    vnet = {
      id   = azurerm_virtual_network.vnet.id
      name = azurerm_virtual_network.vnet.name
      subnet = {
        name = azurerm_subnet.sn1.name
        id   = azurerm_subnet.sn1.id
      }
    }
    nva = {
      dns = {
        # by representing the dns records by router it becomes clear that some names have multiple records (A and AAAA)
        (cloudflare_dns_record.nvadns4.name)   = [cloudflare_dns_record.nvadns4.content, cloudflare_dns_record.nvadns6.content]
        (cloudflare_dns_record.nvadnsi4.name)  = [cloudflare_dns_record.nvadnsi4.content, cloudflare_dns_record.nvadnsi6.content]
        (cloudflare_dns_record.nvadns44.name)  = cloudflare_dns_record.nvadns44.content
        (cloudflare_dns_record.nvadns66.name)  = cloudflare_dns_record.nvadns66.content
        (cloudflare_dns_record.nvadnsi44.name) = cloudflare_dns_record.nvadnsi44.content
        (cloudflare_dns_record.nvadnsi66.name) = cloudflare_dns_record.nvadnsi66.content
      }
      addresses = {
        private = {
          ipv4 = azurerm_network_interface.nvanic1.ip_configuration[0].private_ip_address
          ipv6 = azurerm_network_interface.nvanic1.ip_configuration[1].private_ip_address
        }
        public = {
          ipv4 = azurerm_public_ip.nvapip4.ip_address
          ipv6 = azurerm_public_ip.nvapip6.ip_address
        }
      }
    }
  })
}
