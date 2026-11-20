# per-dataset vault in the team RG; engineers/analysts administer secrets
resource "azurerm_key_vault" "this" {
  name                          = var.names.vault
  location                      = azurerm_resource_group.this.location
  resource_group_name           = azurerm_resource_group.this.name
  tenant_id                     = var.tenant_id
  sku_name                      = "standard"
  rbac_authorization_enabled    = true
  public_network_access_enabled = true
  purge_protection_enabled      = false
  soft_delete_retention_days    = 7
}
resource "azurerm_role_assignment" "owner_app" {
  scope                = azurerm_key_vault.this.id
  role_definition_name = "Key Vault Administrator"
  principal_id         = var.owner_app_object_id
}
resource "azurerm_role_assignment" "owner_group" {
  scope                = azurerm_key_vault.this.id
  role_definition_name = "Key Vault Administrator"
  principal_id         = var.owner_group_object_id
}
resource "azurerm_role_assignment" "role_admins" {
  for_each             = var.role_admin_object_ids
  scope                = azurerm_key_vault.this.id
  role_definition_name = "Key Vault Administrator"
  principal_id         = each.value
}
