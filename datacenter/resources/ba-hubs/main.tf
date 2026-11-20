# ba-locations/main.tf - create a [private ip] point of presence in azure regions
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
  provider     = azurerm.corp
}
# our predecessor
data "terraform_remote_state" "aa_config" {
  backend = "azurerm"
  config = {
    resource_group_name  = var.resource_group_name
    storage_account_name = var.storage_account_name
    container_name       = var.project_name
    key                  = "aa-config.tfstate"
    use_azuread_auth     = true
    tenant_id            = var.tenant_id
    subscription_id      = var.subscription_id
  }
}
module "mesh_members" {
  source     = "../shared/mesh_members"
  dns_domain = local.org.about.dns_domain
  locations  = local.config.locations
  offices    = local.offices
}
# create a hub in each location
module "datacenter_hub" {
  source   = "./hub"
  for_each = toset(keys(local.config.locations))
  dc_secrets = {
    for secret_name in local.project.credentials.secret_names :
    secret_name => data.azurerm_key_vault_secret.dc_secrets[secret_name].value
  }
  hub = {
    name   = each.key
    config = local.config.locations[each.key]
  }
  members = module.mesh_members.members
  config = {
    org        = local.org
    project    = local.project_view
    project_ca = data.azurerm_key_vault_certificate_data.datacenter_cacert
  }
}
