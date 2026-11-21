# resources for az locations, ahem, datacenters
data "azurerm_key_vault_secret" "config_init" {
  name         = "${var.project_name}-config"
  key_vault_id = var.corp_vault_id
  provider     = azurerm.corp
}
data "azurerm_key_vault_secret" "owner_p12" {
  name         = local.config.projects.projects.secret_names.secrets.owner_p12
  key_vault_id = var.corp_vault_id
  provider     = azurerm.corp
}
data "azurerm_key_vault_secret" "dc_secrets" {
  for_each     = toset(local.project.credentials.secret_names)
  name         = each.value
  key_vault_id = var.corp_vault_id
  provider     = azurerm.corp
}
data "azurerm_key_vault_certificate_data" "datacenter_cacert" {
  name         = local.config.projects.projects.secret_names.certs.project_ca
  key_vault_id = var.corp_vault_id
}
data "azuread_client_config" "current" {}
module "scope_roles" {
  source          = "../../catalog/terraform/modules/scope_enumerator"
  tree            = local.config.scopes
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
    local.config.projects.projects.identity.owner.user_object_id,
    local.config.projects.projects.identity.owner.app_object_id
  ]
}
# main resource group for the project
resource "azurerm_resource_group" "project_rg" {
  location = local.config.azure.rg.location
  name     = local.config.azure.rg.name
}
# role assignments on the resource group
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
# vault for the project
resource "azurerm_key_vault" "project_kv" {
  name                       = "kv-${local.org.name}-${var.project_name}"
  location                   = azurerm_resource_group.project_rg.location
  resource_group_name        = azurerm_resource_group.project_rg.name
  tenant_id                  = data.azuread_client_config.current.tenant_id
  sku_name                   = "standard"
  purge_protection_enabled   = false
  soft_delete_retention_days = 7
  rbac_authorization_enabled = true
}
# system role assignments on the vault
resource "azurerm_role_assignment" "project_kv_data_roles" {
  for_each = {
    "owner" = {
      principal            = local.config.projects.projects.identity.owner.group_object_id
      role_definition_name = "Key Vault Administrator"
    }
  }
  scope                = azurerm_key_vault.project_kv.id
  role_definition_name = each.value.role_definition_name
  principal_id         = each.value.principal
  principal_type       = "Group"
}
# functional role assignments on the vault
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
      regions = {
        apc = {
          manager = {
            "Key Vault Administrator" = true
          }
        }
      }
    }
  }
}
# private dns zones for the project
resource "azurerm_private_dns_zone" "privatedns" {
  for_each            = toset(local.config.azure.private_dns_zones)
  name                = each.key
  resource_group_name = azurerm_resource_group.project_rg.name
}
