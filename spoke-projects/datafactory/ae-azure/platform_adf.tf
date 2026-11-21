# shared SHIR: host ADF owns the IR; one Windows VM registers to it
resource "azurerm_data_factory_integration_runtime_self_hosted" "shir" {
  name            = local.resource_names.az.shir_ir
  data_factory_id = module.platform_adf.factory_id
  description     = "Shared self-hosted integration runtime for ${local.project.name} dataset factories"
}
resource "random_password" "shir_admin" {
  length           = 24
  special          = true
  override_special = "!#$%&*()-_=+[]{}"
}
resource "azurerm_key_vault_secret" "shir_admin_username" {
  name         = "shirAdminUsername"
  value        = "shirAdmin"
  key_vault_id = local.config.roots["am-sfbootstrap"].project_vault_id
}
resource "azurerm_key_vault_secret" "shir_admin_password" {
  name         = "shirAdminPassword"
  value        = random_password.shir_admin.result
  key_vault_id = local.config.roots["am-sfbootstrap"].project_vault_id
}
resource "azurerm_network_interface" "shir" {
  name                           = local.resource_names.az.shir_nic
  location                       = local.config.projects.datacenter.spoke.rg.location
  resource_group_name            = local.config.projects.datacenter.spoke.rg.name
  accelerated_networking_enabled = true
  ip_configuration {
    name                          = "ipconfig4"
    subnet_id                     = local.config.projects.datacenter.spoke.vnet.vn1.subnets.sn1.id
    private_ip_address_allocation = "Dynamic"
    private_ip_address_version    = "IPv4"
    primary                       = true
  }
  ip_configuration {
    name                          = "ipconfigv6"
    subnet_id                     = local.config.projects.datacenter.spoke.vnet.vn1.subnets.sn1.id
    private_ip_address_allocation = "Dynamic"
    private_ip_address_version    = "IPv6"
    primary                       = false
  }
}
resource "cloudflare_dns_record" "shir_46" {
  for_each = { 0 : "A", 1 : "AAAA" }
  zone_id  = data.azurerm_key_vault_secret.dc_secrets["cloudflare-dns-zoneid"].value
  name     = "${local.project.name}shir.${local.org.about.dns_domain}"
  content  = azurerm_network_interface.shir.ip_configuration[each.key].private_ip_address
  type     = each.value
  ttl      = 60
}
resource "terraform_data" "shir_install_script_hash" {
  input = filesha256("${path.module}/scripts/install-shir.ps1")
}
resource "azurerm_windows_virtual_machine" "shir" {
  name                       = local.resource_names.az.shir_vm
  resource_group_name        = local.config.projects.datacenter.spoke.rg.name
  location                   = local.config.projects.datacenter.spoke.rg.location
  size                       = "Standard_B2als_v2"
  admin_username             = azurerm_key_vault_secret.shir_admin_username.value
  admin_password             = azurerm_key_vault_secret.shir_admin_password.value
  allow_extension_operations = true
  license_type               = "Windows_Server"
  identity {
    type = "SystemAssigned"
  }
  network_interface_ids = [azurerm_network_interface.shir.id]
  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Premium_LRS"
    disk_size_gb         = 128
    name                 = local.resource_names.az.shir_osdisk
  }
  source_image_reference {
    publisher = "MicrosoftWindowsServer"
    offer     = "WindowsServer"
    sku       = "2022-datacenter-g2"
    version   = "latest"
  }
  vtpm_enabled = true
  lifecycle {
    ignore_changes       = [admin_password, admin_username]
    replace_triggered_by = [terraform_data.shir_install_script_hash]
  }
}
resource "azurerm_storage_container" "shir_vm" {
  name                  = local.resource_names.az.shir_vm_container
  storage_account_id    = azurerm_storage_account.util.id
  container_access_type = "private"
}
resource "azurerm_role_assignment" "shir_vm_blob" {
  scope                = azurerm_storage_container.shir_vm.id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = azurerm_windows_virtual_machine.shir.identity[0].principal_id
  principal_type       = "ServicePrincipal"
}
# RBAC list can lag the assignment write; Run Command uploads stdout once the role is listed
module "shir_vm_blob_rbac" {
  source               = "../../../catalog/terraform/modules/az/wait_for_rbac"
  scope                = azurerm_storage_container.shir_vm.id
  role_definition_name = "Storage Blob Data Contributor"
  object_id            = azurerm_windows_virtual_machine.shir.identity[0].principal_id
  assignment_id        = azurerm_role_assignment.shir_vm_blob.id
}
# leftover node from a replaced VM; 404 on first apply is success
resource "azapi_resource_action" "shir_drop_node" {
  type             = "Microsoft.DataFactory/factories/integrationRuntimes/nodes@2018-06-01"
  resource_id      = "${azurerm_data_factory_integration_runtime_self_hosted.shir.id}/nodes/${local.resource_names.az.shir_vm}"
  method           = "DELETE"
  ignore_not_found = true
  lifecycle {
    replace_triggered_by = [azurerm_windows_virtual_machine.shir.id]
  }
}
resource "azurerm_virtual_machine_extension" "shir_aad_login" {
  name                      = "AADLogin"
  virtual_machine_id        = azurerm_windows_virtual_machine.shir.id
  publisher                 = "Microsoft.Azure.ActiveDirectory"
  type                      = "AADLoginForWindows"
  type_handler_version      = "2.2"
  automatic_upgrade_enabled = false
}
# one-shot install; a failed POST leaves no runCommands/shir-install to delete
resource "azapi_resource_action" "shir_install" {
  type        = "Microsoft.Compute/virtualMachines@2024-07-01"
  resource_id = azurerm_windows_virtual_machine.shir.id
  action      = "runCommand"
  method      = "POST"
  body = {
    commandId = "RunPowerShellScript"
    script    = [file("${path.module}/scripts/install-shir.ps1")]
    parameters = [
      { name = "irAuthKey1", value = azurerm_data_factory_integration_runtime_self_hosted.shir.primary_authorization_key },
      { name = "name", value = azurerm_windows_virtual_machine.shir.name },
    ]
  }
  depends_on = [
    azurerm_virtual_machine_extension.shir_aad_login,
    module.platform_adf,
    azapi_resource_action.shir_drop_node,
  ]
  lifecycle {
    replace_triggered_by = [
      azurerm_windows_virtual_machine.shir.id,
      azurerm_data_factory_integration_runtime_self_hosted.shir.id,
      terraform_data.shir_install_script_hash,
    ]
  }
  timeouts {
    create = "90m"
  }
}
