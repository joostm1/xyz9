# team RG; RG Owner is not Key Vault data plane
resource "azurerm_resource_group" "this" {
  name     = var.names.rg
  location = var.location
}
resource "azurerm_role_assignment" "rg_owner" {
  scope                = azurerm_resource_group.this.id
  role_definition_name = "Owner"
  principal_id         = var.owner_group_object_id
}
