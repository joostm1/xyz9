# one ADF in the team RG; links the shared SHIR and can write the ext-stage
module "adf" {
  source = "../../modules/adf"
  kind   = "dataset"
  factory = {
    name                = var.names.adf
    location            = azurerm_resource_group.this.location
    resource_group_name = azurerm_resource_group.this.name
    global_parameters = {
      DATASET_KEY = {
        type  = "String"
        value = var.dataset_key
      }
      PROJECT_NAME = {
        type  = "String"
        value = var.project_name
      }
    }
  }
  devops = var.devops
  deploy = {
    identity_name     = var.names.adf_deploy
    tenant_id         = var.tenant_id
    resource_group_id = azurerm_resource_group.this.id
    subscription      = var.subscription
  }
  shir = {
    name        = var.names.shir_ir
    resource_id = var.shir_ir_id
  }
  connections = {
    project_name                               = var.project_name
    project_vault_uri                          = var.project_vault_uri
    account_identifier_privatelink_secret_name = var.account_identifier_privatelink_secret_name
    account_identifier_privatelink_secret_id   = var.account_identifier_privatelink_secret_id
    adf_key_secret_name                        = azurerm_key_vault_secret.adf_key.name
    snowflake_database                         = upper(var.dataset_key)
    snowflake_role                             = snowflake_service_user.adf.default_role
    snowflake_user                             = snowflake_service_user.adf.name
    snowflake_warehouse                        = snowflake_service_user.adf.default_warehouse
    ext_stage_id                               = var.ext_stage_id
    ext_stage_account_name                     = var.ext_stage_account_name
  }
  dataset = {
    dataset_key       = var.dataset_key
    dataset_vault_id  = azurerm_key_vault.this.id
    dataset_vault_uri = azurerm_key_vault.this.vault_uri
  }
}
