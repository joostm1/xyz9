# typed git seed: publish_config creates develop; remaining files follow
# ignore commit_message: provider read returns branch HEAD, so per-file messages chase each other
locals {
  ir_type_properties = var.kind == "dataset" ? {
    linkedInfo = {
      authorizationType = "Rbac"
      resourceId        = var.shir.resource_id
    }
  } : {}
  snowflake_key_vault_ls = var.kind == "dataset" ? "ls_vault_${var.dataset.dataset_key}" : "ls_vault_${var.connections.project_name}"
  files = merge(
    {
      factory = {
        file           = "factory/${azurerm_data_factory.this.name}.json"
        commit_message = "Seed ADF factory/${azurerm_data_factory.this.name}.json"
        content = jsonencode({
          identity = {
            principalId = azurerm_data_factory.this.identity[0].principal_id
            tenantId    = azurerm_data_factory.this.identity[0].tenant_id
            type        = "SystemAssigned"
          }
          location = azurerm_data_factory.this.location
          name     = azurerm_data_factory.this.name
          properties = {
            globalParameters = var.factory.global_parameters
          }
        })
      }
      ir_shir = {
        file           = "integrationRuntime/${var.shir.name}.json"
        commit_message = "Seed ADF integrationRuntime/${var.shir.name}.json"
        content = jsonencode({
          name = var.shir.name
          properties = {
            description    = coalesce(var.shir.description, "Integration runtime")
            type           = "SelfHosted"
            typeProperties = local.ir_type_properties
          }
        })
      }
      ls_vault_project = {
        file           = "linkedService/ls_vault_${var.connections.project_name}.json"
        commit_message = "Seed ADF ls_vault_${var.connections.project_name}.json"
        content = jsonencode({
          name = "ls_vault_${var.connections.project_name}"
          properties = {
            connectVia = {
              referenceName = var.shir.name
              type          = "IntegrationRuntimeReference"
            }
            type = "AzureKeyVault"
            typeProperties = {
              baseUrl = var.connections.project_vault_uri
            }
          }
          type = "Microsoft.DataFactory/factories/linkedservices"
        })
      }
      ls_snowflake = {
        file           = "linkedService/ls_snowflake.json"
        commit_message = "Seed ADF ls_snowflake.json"
        content = jsonencode({
          name = "ls_snowflake"
          properties = {
            connectVia = {
              referenceName = var.shir.name
              type          = "IntegrationRuntimeReference"
            }
            type = "SnowflakeV2"
            typeProperties = {
              accountIdentifier = {
                secretName = var.connections.account_identifier_privatelink_secret_name
                store = {
                  referenceName = "ls_vault_${var.connections.project_name}"
                  type          = "LinkedServiceReference"
                }
                type = "AzureKeyVaultSecret"
              }
              authenticationType = "KeyPair"
              database           = var.connections.snowflake_database
              privateKey = {
                secretName = var.connections.adf_key_secret_name
                store = {
                  referenceName = local.snowflake_key_vault_ls
                  type          = "LinkedServiceReference"
                }
                type = "AzureKeyVaultSecret"
              }
              role      = var.connections.snowflake_role
              user      = var.connections.snowflake_user
              warehouse = var.connections.snowflake_warehouse
            }
            version = "1.1"
          }
          type = "Microsoft.DataFactory/factories/linkedservices"
        })
      }
      ls_blob_ext_stage = {
        file           = "linkedService/ls_blob_ext_stage.json"
        commit_message = "Seed ADF ls_blob_ext_stage.json"
        content = jsonencode({
          name = "ls_blob_ext_stage"
          properties = {
            connectVia = {
              referenceName = var.shir.name
              type          = "IntegrationRuntimeReference"
            }
            type = "AzureBlobStorage"
            typeProperties = {
              accountKind        = "StorageV2"
              authenticationType = "MSI"
              serviceEndpoint    = "https://${var.connections.ext_stage_account_name}.blob.core.windows.net/"
            }
          }
          type = "Microsoft.DataFactory/factories/linkedservices"
        })
      }
      pipeline = {
        file           = "azure-pipelines.yml"
        commit_message = "Seed ADF azure-pipelines.yml"
        content        = <<-EOT
        resources:
          repositories:
            - repository: shared
              type: git
              name: ${var.devops.shared_repository_name}
              ref: refs/heads/main
        trigger:
          - develop
        extends:
          template: pipelines/adf-publish.yml@shared
        EOT
      }
    },
    var.dataset == null ? {} : {
      ls_vault_dataset = {
        file           = "linkedService/ls_vault_${var.dataset.dataset_key}.json"
        commit_message = "Seed ADF ls_vault_${var.dataset.dataset_key}.json"
        content = jsonencode({
          name = "ls_vault_${var.dataset.dataset_key}"
          properties = {
            connectVia = {
              referenceName = var.shir.name
              type          = "IntegrationRuntimeReference"
            }
            type = "AzureKeyVault"
            typeProperties = {
              baseUrl = var.dataset.dataset_vault_uri
            }
          }
          type = "Microsoft.DataFactory/factories/linkedservices"
        })
      }
    }
  )
}
resource "azuredevops_git_repository_file" "bootstrap" {
  repository_id       = var.devops.repository_id
  file                = "publish_config.json"
  content             = jsonencode({ publishBranch = "develop" })
  branch              = var.branch
  commit_message      = "Seed ADF publish_config.json"
  overwrite_on_create = true
  lifecycle {
    ignore_changes = [commit_message]
    precondition {
      condition     = var.kind != "dataset" || var.dataset != null
      error_message = "dataset is required when kind is dataset."
    }
    precondition {
      condition     = var.kind != "platform" || var.dataset == null
      error_message = "dataset must be omitted when kind is platform."
    }
    precondition {
      condition     = var.kind != "dataset" || try(var.shir.resource_id, "") != ""
      error_message = "shir.resource_id is required when kind is dataset."
    }
    precondition {
      condition     = var.kind != "platform" || coalesce(var.connections.project_vault_id, "") != ""
      error_message = "connections.project_vault_id is required when kind is platform."
    }
  }
}
resource "azuredevops_git_repository_file" "this" {
  for_each            = local.files
  repository_id       = var.devops.repository_id
  file                = each.value.file
  content             = each.value.content
  branch              = var.branch
  commit_message      = each.value.commit_message
  overwrite_on_create = true
  depends_on          = [azuredevops_git_repository_file.bootstrap]
  lifecycle {
    ignore_changes = [commit_message]
  }
}
