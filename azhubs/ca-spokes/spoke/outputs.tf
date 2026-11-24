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
    subscription = {
      id   = data.azurerm_subscription.current.subscription_id
      name = data.azurerm_subscription.current.display_name
    }
    vault = {
      id   = var.project.vault.id
      name = var.project.vault.name
    }
    owner_group = {
      object_id = var.spoke.owner_group_object_id
    }
    owner_user = {
      object_id = data.azuread_user.owner.object_id
    }
    client = {
      application = {
        client_id = azuread_application.client.client_id
      }
      service_principal = {
        object_id = azuread_service_principal.client.object_id
      }
      p12 = {
        name = azurerm_key_vault_secret.client_p12.name
      }
    }
  }
}
