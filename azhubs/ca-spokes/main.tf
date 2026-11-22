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
# for_each hub and matching spokes
module "spoke" {
  for_each = {
    for item in flatten([
      for location in keys(local.hub_locations) : [
        for spoke_project in local.spoke_projects :
        {
          key           = "${location}-${spoke_project.name}"
          hub_location  = location
          spoke_name    = spoke_project.name
          spoke_project = spoke_project
        } if spoke_project.hub_location == location
      ]
    ]) : item.key => item
  }
  source = "./spoke"
  spoke = {
    name    = each.value.spoke_name
    project = local.spoke_config[each.value.spoke_name]
  }
  hub = {
    name   = each.value.hub_location
    config = local.hub_locations[each.value.hub_location]
  }
  project = local.project_view
}
