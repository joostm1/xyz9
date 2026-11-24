output "config" {
  value = merge(local.project, {
    roots = merge(try(local.project.roots, {}), {
      (var.state_key) = {
        owner = {
          user = {
            object_id = data.azuread_user.owner.object_id
          }
          application = {
            client_id = azuread_application.owner.client_id
          }
          service_principal = {
            object_id = azuread_service_principal.owner.object_id
          }
          group = {
            object_id = azuread_group.owner.object_id
          }
          p12 = {
            name = azurerm_key_vault_secret.owner_p12.name
          }
        }
        project_ca = {
          name = azurerm_key_vault_certificate.project_ca.name
        }
      }
    })
  })
}
