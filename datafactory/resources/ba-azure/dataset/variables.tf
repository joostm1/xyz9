variable "dataset_key" {
  type = string
}
variable "project_name" {
  type = string
}
variable "location" {
  type = string
}
variable "names" {
  type = object({
    rg         = string
    adf        = string
    vault      = string
    adf_pe     = string
    adf_deploy = string
    shir_ir    = string
  })
}
variable "tenant_id" {
  type = string
}
variable "owner_app_object_id" {
  type = string
}
variable "owner_group_object_id" {
  type = string
}
variable "subscription" {
  type = object({
    id   = string
    name = string
  })
}
variable "subnet_id" {
  type = string
}
variable "role_admin_object_ids" {
  type = map(string)
}
variable "shir_ir_id" {
  type = string
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
variable "project_vault_uri" {
  type = string
}
variable "account_identifier_privatelink_secret_name" {
  type = string
}
variable "account_identifier_privatelink_secret_id" {
  type = string
}
variable "ext_stage_id" {
  type = string
}
variable "ext_stage_account_name" {
  type = string
}
