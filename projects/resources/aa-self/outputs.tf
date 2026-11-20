# Root-module handoff: catalog fields at top level; this root nests under roots[var.state_key]
output "config" {
  value = merge(local.config, {
    roots = merge(try(local.config.roots, {}), {
      (var.state_key) = {
        identity = {
          owner = {
            user_object_id  = data.azuread_user.owner.object_id
            app_object_id   = azuread_service_principal.owner.object_id
            app_client_id   = azuread_service_principal.owner.client_id
            group_object_id = azuread_group.owner_group.object_id
          }
        }
        secret_names = {
          certs = {
            project_ca = azurerm_key_vault_certificate.project_ca.name
            owner_cert = azurerm_key_vault_certificate.owner_cert.name
          }
          secrets = {
            owner_p12 = azurerm_key_vault_secret.owner_p12.name
          }
        }
        azurerm = {
          iac = {
            subscription = {
              id   = local.subscriptions_map["xyz9-iac"].subscription_id
              name = local.subscriptions_map["xyz9-iac"].display_name
            }
          }
          project = {
            mg = {
              id   = azurerm_management_group.projects.id
              name = azurerm_management_group.projects.display_name
            }
            subscription = {
              id   = azurerm_subscription.project.subscription_id
              name = azurerm_subscription.project.subscription_name
            }
            # MSDN landing zone shared by every project; List API hides MG-inherited subs from the owner SP
            shared_subscription = {
              id   = local.subscriptions_map[local.projects_subscription_name].subscription_id
              name = local.subscriptions_map[local.projects_subscription_name].display_name
            }
          }
        }
      }
    })
  })
}
