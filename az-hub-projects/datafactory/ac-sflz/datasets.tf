# per-dataset warehouses, monitors, warehouse roles, and dataset databases
module "warehouse_x_dataset" {
  source = "../../../../aa-catalog/catalog/terraform/modules/map_join"
  left = {
    for dataset_key in keys(local.config.scopes.datasets) : dataset_key => {
      dataset_key = dataset_key
      join_key    = "all" # cross join
    }
  }
  right = {
    for warehouse_key, profile in local.config.snowflake.datasets.warehouses : warehouse_key => merge(profile, {
      warehouse_key = warehouse_key
      join_key      = "all" # cross join
    })
  }
  left_match_attr  = "join_key"
  right_match_attr = "join_key"
  key_attrs        = ["dataset_key", "warehouse_key"]
}
resource "snowflake_resource_monitor" "dataset_warehouse" {
  for_each                  = module.warehouse_x_dataset.by_key
  name                      = upper("${each.value.dataset_key}_${each.value.warehouse_key}")
  credit_quota              = local.config.snowflake.datasets.resource_monitors[each.value.resource_monitor].credit_quota
  frequency                 = local.config.snowflake.datasets.resource_monitors[each.value.resource_monitor].frequency
  start_timestamp           = try(local.config.snowflake.datasets.resource_monitors[each.value.resource_monitor].start_timestamp, "IMMEDIATELY")
  notify_triggers           = local.config.snowflake.datasets.resource_monitors[each.value.resource_monitor].notify_triggers
  suspend_trigger           = local.config.snowflake.datasets.resource_monitors[each.value.resource_monitor].suspend_trigger
  suspend_immediate_trigger = local.config.snowflake.datasets.resource_monitors[each.value.resource_monitor].suspend_immediate_trigger
  provider                  = snowflake.accountadmin
}
# each dataset gets a warehouse of each profile ["ingest", "transform", "reporting"]
resource "snowflake_warehouse" "dataset_warehouse" {
  for_each       = module.warehouse_x_dataset.by_key
  name           = upper("${each.value.dataset_key}_${each.value.warehouse_key}")
  warehouse_size = each.value.size
  auto_suspend   = each.value.auto_suspend
  auto_resume    = tostring(each.value.auto_resume)
  resource_monitor = snowflake_resource_monitor.dataset_warehouse[
    each.key
  ].fully_qualified_name
  comment  = "${each.value.warehouse_key} warehouse for dataset ${each.value.dataset_key}."
  provider = snowflake.accountadmin
}
# each warehouse gets a role
resource "snowflake_account_role" "dataset_warehouse_role" {
  for_each = module.warehouse_x_dataset.by_key
  name     = upper("${each.value.dataset_key}_${each.value.warehouse_key}")
  comment  = "Warehouse role for ${each.value.warehouse_key} profile."
  provider = snowflake.securityadmin
}
# grant dataset warehouse privileges to the accompanying roles
resource "snowflake_grant_privileges_to_account_role" "warehouse_usage" {
  for_each          = module.warehouse_x_dataset.by_key
  account_role_name = snowflake_account_role.dataset_warehouse_role[each.key].name
  privileges        = ["USAGE"]
  on_account_object {
    object_type = "WAREHOUSE"
    object_name = snowflake_warehouse.dataset_warehouse[each.key].name
  }
  provider = snowflake.securityadmin
}
# enumerate the parent roles for each warehouse profile, e.g., "reporting-engineer", "reporting-analyst"
module "warehouse_parent_roles_enumerated" {
  source          = "../../../../aa-catalog/catalog/terraform/modules/scope_enumerator"
  tree            = local.config.snowflake.datasets.warehouses
  enum_key        = "parent_dataset_roles"
  enum_value_name = "parent_role"
}
# enumerate the roles for each dataset, e.g., "dataset1-analyst", "dataset1-engineer"
module "dataset_roles_enumerated" {
  source          = "../../../../aa-catalog/catalog/terraform/modules/scope_enumerator"
  tree            = local.project.scopes.datasets
  enum_key        = "roles"
  enum_value_name = "role"
}
module "warehouse_role_parent_matrix" {
  source = "../../../../aa-catalog/catalog/terraform/modules/map_join"
  left = {
    for key, role in module.dataset_roles_enumerated.by_key : key => {
      dataset_key     = role.path_key
      parent_role_key = key
      role_key        = role.role
    }
  }
  right = {
    for key, grant in module.warehouse_parent_roles_enumerated.by_key : key => {
      warehouse_key = grant.path_key
      role_key      = grant.parent_role
    }
  }
  left_match_attr  = "role_key"
  right_match_attr = "role_key"
  key_attrs        = ["dataset_key", "warehouse_key", "parent_role_key"]
}
resource "snowflake_grant_account_role" "warehouse_role_parents" {
  for_each         = module.warehouse_role_parent_matrix.by_key
  role_name        = snowflake_account_role.dataset_warehouse_role["${each.value.dataset_key}-${each.value.warehouse_key}"].name
  parent_role_name = snowflake_account_role.project_roles["dataset-${each.value.parent_role_key}"].name
  provider         = snowflake.securityadmin
}
resource "snowflake_database" "dataset" {
  for_each = local.config.scopes.datasets
  name     = upper(each.key)
  comment  = "Database for dataset ${each.key}"
  provider = snowflake.sysadmin
}
# ingest warehouse role needs DATABASE USAGE so the ADF service user can connect
resource "snowflake_grant_privileges_to_account_role" "dataset_database_ingest_usage" {
  for_each          = local.config.scopes.datasets
  account_role_name = snowflake_account_role.dataset_warehouse_role["${each.key}-ingest"].name
  privileges        = ["USAGE"]
  on_account_object {
    object_type = "DATABASE"
    object_name = snowflake_database.dataset[each.key].name
  }
  provider = snowflake.sysadmin
}
# resource "snowflake_grant_privileges_to_account_role" "dataset_database_usage" {
#   for_each          = module.dataset_roles.by_key
#   account_role_name = snowflake_account_role.project_roles[each.key].name
#   privileges        = ["USAGE"]
#   on_account_object {
#     object_type = "DATABASE"
#     object_name = snowflake_database.datasets[each.value.path[1]].name
#   }
#   provider = snowflake.sysadmin
# }
# resource "snowflake_grant_privileges_to_account_role" "dataset_database_warehouse_usage" {
#   for_each          = local.dataset_warehouses
#   account_role_name = snowflake_account_role.warehouse_roles[each.value.warehouse_key].name
#   privileges        = ["USAGE"]
#   on_account_object {
#     object_type = "DATABASE"
#     object_name = snowflake_database.datasets[each.value.dataset_key].name
#   }
#   provider = snowflake.sysadmin
# }
# resource "snowflake_schema" "dataset_schemas" {
#   for_each = local.dataset_schemas
#   name     = each.value.schema_name
#   database = snowflake_database.datasets[each.value.dataset_key].name
#   comment  = each.value.comment
#   provider = snowflake.sysadmin
# }
# resource "snowflake_grant_privileges_to_account_role" "dataset_schema_dataset_role_privileges" {
#   for_each          = local.dataset_schema_dataset_role_grants
#   account_role_name = snowflake_account_role.project_roles[each.value.parent_role_key].name
#   privileges        = each.value.privileges
#   on_schema {
#     schema_name = snowflake_schema.dataset_schemas[each.value.schema_key].fully_qualified_name
#   }
#   provider = snowflake.sysadmin
# }
# resource "snowflake_grant_privileges_to_account_role" "dataset_schema_warehouse_role_privileges" {
#   for_each          = local.dataset_schema_warehouse_role_grants
#   account_role_name = snowflake_account_role.warehouse_roles[each.value.warehouse_key].name
#   privileges        = each.value.privileges
#   on_schema {
#     schema_name = snowflake_schema.dataset_schemas[each.value.schema_key].fully_qualified_name
#   }
#   provider = snowflake.sysadmin
# }
# resource "snowflake_grant_privileges_to_account_role" "dataset_schema_future_object_dataset_role_privileges" {
#   for_each          = local.dataset_schema_future_object_dataset_role_grants
#   account_role_name = snowflake_account_role.project_roles[each.value.parent_role_key].name
#   privileges        = each.value.privileges
#   on_schema_object {
#     future {
#       object_type_plural = each.value.object_type_plural
#       in_schema          = snowflake_schema.dataset_schemas[each.value.schema_key].fully_qualified_name
#     }
#   }
#   provider = snowflake.securityadmin
# }
# resource "snowflake_grant_privileges_to_account_role" "dataset_schema_future_object_warehouse_role_privileges" {
#   for_each          = local.dataset_schema_future_object_warehouse_role_grants
#   account_role_name = snowflake_account_role.warehouse_roles[each.value.warehouse_key].name
#   privileges        = each.value.privileges
#   on_schema_object {
#     future {
#       object_type_plural = each.value.object_type_plural
#       in_schema          = snowflake_schema.dataset_schemas[each.value.schema_key].fully_qualified_name
#     }
#   }
#   provider = snowflake.securityadmin
# }
