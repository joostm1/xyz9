variable "kind" {
  type        = string
  description = "Factory shape: dataset (linked SHIR + dataset vault) or platform (native SHIR in git)."
  validation {
    condition     = contains(["dataset", "platform"], var.kind)
    error_message = "kind must be dataset or platform."
  }
}
variable "branch" {
  type    = string
  default = "refs/heads/develop"
}
variable "factory" {
  type = object({
    name                = string
    location            = string
    resource_group_name = string
    global_parameters = optional(map(object({
      type  = string
      value = string
    })), {})
  })
}
variable "devops" {
  type = object({
    org_name               = string
    project_id             = string
    project_name           = string
    repository_id          = string
    repository_name        = string
    shared_repository_id   = string
    shared_repository_name = string
    tenant_id              = string
  })
}
variable "deploy" {
  type = object({
    identity_name     = string
    tenant_id         = string
    resource_group_id = string
    subscription = object({
      id   = string
      name = string
    })
  })
}
variable "shir" {
  type = object({
    name        = string
    description = optional(string)
    resource_id = optional(string)
  })
}
variable "connections" {
  type = object({
    project_name                               = string
    project_vault_uri                          = string
    project_vault_id                           = optional(string)
    account_identifier_privatelink_secret_name = string
    account_identifier_privatelink_secret_id   = string
    adf_key_secret_name                        = string
    snowflake_database                         = string
    snowflake_role                             = string
    snowflake_user                             = string
    snowflake_warehouse                        = string
    ext_stage_id                               = string
    ext_stage_account_name                     = string
  })
}
variable "dataset" {
  type = object({
    dataset_key       = string
    dataset_vault_id  = string
    dataset_vault_uri = string
  })
  default = null
}
