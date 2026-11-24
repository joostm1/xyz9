# Install generated IPsec mesh files on office EdgeRouters.
data "azurerm_key_vault_secret" "owner_p12" {
  name         = local.config.roots["aa-foundation"].owner.p12.name
  key_vault_id = var.corp_vault_id
  provider     = azurerm.corp
}
data "azurerm_key_vault_secret" "office_ssh" {
  for_each     = toset(["nvaAdminUserName", "adminPK"])
  name         = each.value
  key_vault_id = var.corp_vault_id
  provider     = azurerm.corp
}
data "azurerm_key_vault_certificate_data" "datacenter_cacert" {
  name         = local.config.roots["aa-foundation"].project_ca.name
  key_vault_id = var.corp_vault_id
  provider     = azurerm.corp
}
# our predecessor
data "terraform_remote_state" "am_foundation" {
  backend = "azurerm"
  config = {
    resource_group_name  = var.resource_group_name
    storage_account_name = var.storage_account_name
    container_name       = var.project_name
    key                  = "am-foundation.tfstate"
    use_azuread_auth     = true
    tenant_id            = var.tenant_id
    subscription_id      = split("/", var.corp_vault_id)[2]
  }
}
data "terraform_remote_state" "ba_hubs" {
  backend = "azurerm"
  config = {
    resource_group_name  = var.resource_group_name
    storage_account_name = var.storage_account_name
    container_name       = var.project_name
    key                  = "ba-hubs.tfstate"
    use_azuread_auth     = true
    tenant_id            = var.tenant_id
    subscription_id      = split("/", var.corp_vault_id)[2]
  }
}
module "mesh_members" {
  source     = "../shared/mesh_members"
  dns_domain = local.org.about.dns_domain
  hubs       = local.config.hubs
  offices    = local.offices
}
module "office" {
  source   = "./office"
  for_each = local.offices
  office = {
    name   = each.key
    config = each.value
  }
  members      = module.mesh_members.members
  hub_dns_ipv4 = local.hub_dns_ipv4
  hub_dns_ipv6 = local.hub_dns_ipv6
  ssh = {
    host        = module.mesh_members.members[each.key].id
    user        = data.azurerm_key_vault_secret.office_ssh["nvaAdminUserName"].value
    private_key = data.azurerm_key_vault_secret.office_ssh["adminPK"].value
  }
  config = {
    org        = local.org
    project    = local.project_view
    project_ca = data.azurerm_key_vault_certificate_data.datacenter_cacert
  }
}
