# datasets × layers; azure facet is the ingest-container guinea pig
module "dataset_x_layer" {
  source = "../../org/terraform/modules/map_join"
  left = {
    for dataset_key in keys(local.config.scopes.datasets) : dataset_key => {
      dataset_key = dataset_key
      join_key    = "all"
    }
  }
  right = {
    for layer_key, layer in local.project.layers : layer_key => merge(layer, {
      layer_key = layer_key
      join_key  = "all"
    })
  }
  left_match_attr  = "join_key"
  right_match_attr = "join_key"
  key_attrs        = ["dataset_key", "layer_key"]
}
module "dataset_x_layer_azure" {
  source = "../../org/terraform/modules/map_join"
  left   = module.dataset_x_layer.by_key
  right = {
    for layer_key, layer in local.project.layers : layer_key => merge(layer.azure, {
      layer_key = layer_key
      schema    = layer.snowflake.schema
    }) if contains(keys(layer), "azure")
  }
  left_match_attr  = "layer_key"
  right_match_attr = "layer_key"
  key_attrs        = ["dataset_key", "layer_key"]
}
resource "azurerm_storage_container" "layer" {
  for_each              = module.dataset_x_layer_azure.by_key
  name                  = "${each.value.dataset_key}-${each.value.container}"
  storage_account_id    = azurerm_storage_account.sflz_external_stage.id
  container_access_type = "private"
}
module "layer_azure_x_dataset_role" {
  source = "../../org/terraform/modules/map_join"
  left   = module.dataset_x_layer_azure.by_key
  right = merge([
    for schema_key, schema in local.project.snowflake.datasets.schemas : {
      for role in keys(try(schema.schema_privileges.dataset_roles, {})) :
      "${schema_key}-${role}" => {
        schema = schema_key
        role   = role
      }
    }
  ]...)
  left_match_attr  = "schema"
  right_match_attr = "schema"
  key_attrs        = ["dataset_key", "layer_key", "role"]
}
resource "azurerm_role_assignment" "layer_container_dataset_role" {
  for_each             = module.layer_azure_x_dataset_role.by_key
  scope                = azurerm_storage_container.layer["${each.value.dataset_key}-${each.value.layer_key}"].id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = azuread_group.project_roles["dataset-${each.value.dataset_key}-${each.value.role}"].object_id
}
