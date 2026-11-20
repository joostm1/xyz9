# same-project handoff: full living object with this root under roots[state_key]
output "config" {
  value = merge(local.config, {
    roots = merge(try(local.config.roots, {}), {
      (var.state_key) = {
        resource_names = local.resource_names
        resource_ids = {
          util = azurerm_storage_account.util.id
        }
        shir = {
          host_adf_id   = module.platform_adf.factory_id
          host_adf_name = module.platform_adf.factory_name
          ir_id         = azurerm_data_factory_integration_runtime_self_hosted.shir.id
          ir_name       = azurerm_data_factory_integration_runtime_self_hosted.shir.name
          vm_id         = azurerm_windows_virtual_machine.shir.id
          private_ip    = azurerm_network_interface.shir.ip_configuration[0].private_ip_address
          fqdn          = cloudflare_dns_record.shir_46[0].name
          creadential_names = {
            shirAdminUsername = azurerm_key_vault_secret.shir_admin_username.name
            shirAdminPassword = azurerm_key_vault_secret.shir_admin_password.name
          }
        }
        platform_adf = {
          user        = snowflake_service_user.platform_adf.name
          secret_name = azurerm_key_vault_secret.platform_adf_key.name
        }
        datasets = {
          for dataset_key, dataset_value in module.datasets : dataset_key => dataset_value.dataset
        }
      }
    })
  })
  sensitive = true
}
