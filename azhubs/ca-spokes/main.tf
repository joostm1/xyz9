# ca-spoke: land projects with a `hub_location` on spoke connected to their desired hub

data "azurerm_key_vault_secret" "owner_p12" {
  name         = local.config.projects.projects.secret_names.secrets.owner_p12
  key_vault_id = var.corp_vault_id
  provider     = azurerm.corp
}
# our predecessor
data "terraform_remote_state" "ba_hubs" {
  backend = "azurerm"
  config = {
    resource_group_name  = var.resource_group_name
    storage_account_name = var.storage_account_name
    container_name       = var.project_name
    key                  = "ba-hubs.tfstate"
    use_azuread_auth     = true
    tenant_id            = var.tenant_id
    subscription_id      = var.subscription_id
  }
}
# Resolve owner groups from spoke project seeds.
data "azuread_group" "spoke_owners" {
  for_each     = local.spoke_projects
  display_name = each.value.owner_group
}
# for_each hub and matching spokes
module "spoke" {
  for_each = {
    for item in flatten([
      for hub in keys(local.hubs) : [
        for spoke_project in local.spoke_projects :
        {
          key           = "${hub}-${spoke_project.name}"
          hub_location  = hub
          spoke_name    = spoke_project.name
          spoke_project = spoke_project
        } if spoke_project.hub_location == hub
      ]
    ]) : item.key => item
  }
  source = "./spoke"
  spoke = {
    name                  = each.value.spoke_name
    project               = each.value.spoke_project
    owner_group_object_id = data.azuread_group.spoke_owners[each.value.spoke_name].object_id
  }
  hub = {
    name   = each.value.hub_location
    config = local.hubs[each.value.hub_location]
  }
  project = local.project_view
}
# project boundary: nest under projects.<projectName>
resource "azurerm_key_vault_secret" "spoke_configs" {
  for_each     = local.spoke_projects
  name         = "${each.key}-config"
  key_vault_id = var.corp_vault_id
  content_type = "application/json"
  value = jsonencode(merge(
    local.spoke_projects[each.key],
    {
      projects = merge(try(local.spoke_projects[each.key].projects, {}), {
        (var.project_name) = module.spoke["${each.value.hub_location}-${each.key}"].config
      })
    }
  ))
  provider = azurerm.corp
}
# Grant secrets user to the owner group
resource "azurerm_role_assignment" "spoke_owner_secrets_user" {
  for_each             = local.spoke_projects
  scope                = var.corp_vault_id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = data.azuread_group.spoke_owners[each.key].object_id
  provider             = azurerm.corp
}
