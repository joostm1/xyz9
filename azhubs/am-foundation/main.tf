# aa-foundation publishes the owner app client id and the `azhubs-owner-p12` secret name
data "terraform_remote_state" "aa_foundation" {
  backend = "azurerm"
  config = {
    resource_group_name  = var.resource_group_name
    storage_account_name = var.storage_account_name
    container_name       = var.project_name
    key                  = "aa-foundation.tfstate"
    use_azuread_auth     = true
    tenant_id            = var.tenant_id
    subscription_id      = split("/", var.corp_vault_id)[2]
  }
}
# Read `azhubs-owner-p12` from the corporate vault for client_certificate on the default azurerm provider
data "azurerm_key_vault_secret" "owner_p12" {
  name         = local.config.roots["aa-foundation"].owner.p12.name
  key_vault_id = var.corp_vault_id
  provider     = azurerm.corp
}
module "scope_roles" {
  source          = "../../catalog/terraform/modules/scope_enumerator"
  tree            = local.project.scopes
  enum_key        = "roles"
  enum_value_name = "value"
  segment_translations = {
    locations = ""
  }
}
# functional scope/role groups
resource "azuread_group" "function_scope_role_groups" {
  for_each                = local.scope_role_groups
  display_name            = each.value.display_name
  description             = each.value.description
  security_enabled        = true
  assignable_to_role      = false
  prevent_duplicate_names = true
  owners = [
    local.config.roots["aa-foundation"].owner.user.object_id,
    local.config.roots["aa-foundation"].owner.service_principal.object_id,
  ]
}
resource "azurerm_resource_group" "project_rg" {
  location = local.project.azure.rg.location
  name     = local.project.azure.rg.name
}
resource "azurerm_role_assignment" "owner_group_rg" {
  scope                = azurerm_resource_group.project_rg.id
  role_definition_name = "Owner"
  principal_id         = local.config.roots["aa-foundation"].owner.group.object_id
  principal_type       = "Group"
}
module "rg_role_assignments" {
  source           = "../../catalog/terraform/modules/az/role_assignments"
  entra_groups     = local.entra_scope_role_groups
  assignment_scope = azurerm_resource_group.project_rg.id
  role_assignments = {
    project = {
      admin = {
        "Owner" = true
      }
    }
  }
}
# Create `kv-xyz9-azhubs`
resource "azurerm_key_vault" "project_kv" {
  name                       = "kv-${local.org.name}-${var.project_name}"
  location                   = azurerm_resource_group.project_rg.location
  resource_group_name        = azurerm_resource_group.project_rg.name
  tenant_id                  = var.tenant_id
  sku_name                   = "standard"
  purge_protection_enabled   = false
  soft_delete_retention_days = 7
  rbac_authorization_enabled = true
}
# Grant `azhubs-owners` Key Vault Administrator on `kv-xyz9-azhubs`
resource "azurerm_role_assignment" "project_kv_data_roles" {
  for_each = {
    "owner" = {
      principal            = local.config.roots["aa-foundation"].owner.group.object_id
      role_definition_name = "Key Vault Administrator"
    }
  }
  scope                = azurerm_key_vault.project_kv.id
  role_definition_name = each.value.role_definition_name
  principal_id         = each.value.principal
  principal_type       = "Group"
}
module "kv_role_assignments" {
  source           = "../../catalog/terraform/modules/az/role_assignments"
  entra_groups     = local.entra_scope_role_groups
  assignment_scope = azurerm_key_vault.project_kv.id
  role_assignments = {
    project = {
      admin = {
        "Key Vault Administrator" = true
      }
      engineer = {
        "Key Vault Administrator" = true
      }
    }
  }
}
# private dns zones for the project
resource "azurerm_private_dns_zone" "privatedns" {
  for_each            = toset(local.project.azure.private_dns_zones)
  name                = each.key
  resource_group_name = azurerm_resource_group.project_rg.name
}
