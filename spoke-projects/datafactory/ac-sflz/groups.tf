# Create Entra groups `sg-datafactory-*` once; each Snowflake account SSO app assigns them
resource "azuread_group" "project_roles" {
  for_each         = module.project_roles.by_key
  display_name     = "sg-${var.project_name}-${each.value.name}"
  description      = "security group for the ${each.value.name} role in the snowflake account"
  owners           = toset([local.config.projects.azhubs.owner_user.object_id, local.config.projects.azhubs.client.service_principal.object_id])
  security_enabled = true
}
locals {
  entra_groups = {
    for key, group in azuread_group.project_roles : key => {
      object_id    = group.object_id
      display_name = group.display_name
    }
  }
}
