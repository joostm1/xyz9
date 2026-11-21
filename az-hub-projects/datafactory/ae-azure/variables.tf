# module inputs; same-project config from au-devops remote_state
variable "org_name" {
  type = string
}
variable "state_key" {
  type = string
}
variable "project_name" {
  type = string
}
variable "corp_vault_id" {
  type = string
}
variable "tenant_id" {
  type = string
}
variable "storage_account_name" {
  type = string
}
variable "resource_group_name" {
  type = string
}

locals {
  org     = jsondecode(file("../../../../aa-catalog/catalog/org.json"))
  project = jsondecode(file("../../../../aa-catalog/catalog/projects/${var.project_name}.json"))
  # our predecessor
  config   = data.terraform_remote_state.au_devops.outputs.config
  datasets = local.config.scopes.datasets
  resource_names = {
    az = {
      shir_host_adf = "adf-${local.org.name}-${local.project.name}"
      shir_ir       = "shir"
      shir_vm       = "shir"
      shir_nic      = "shir-nic"
      shir_osdisk   = "shir-osdisk"
      adf = {
        for dataset_key in keys(local.datasets) : dataset_key => "adf-${dataset_key}"
      }
      adf_rg = {
        for dataset_key in keys(local.datasets) : dataset_key => "rg-${local.project.name}-${dataset_key}"
      }
      dataset_vault = {
        for dataset_key in keys(local.datasets) : dataset_key => "kv-${dataset_key}"
      }
      adf_pe = {
        for dataset_key in keys(local.datasets) : dataset_key => "pe-adf-${dataset_key}"
      }
      adf_deploy = {
        for dataset_key in keys(local.datasets) : dataset_key => "id-adf-deploy-${dataset_key}"
      }
      adf_deploy_platform = "id-adf-deploy-platform"
      shir_vm_container   = "shir-vm"
      util                = "sa${local.project.name}util"
      util_pe_blob        = "pe-sa${local.project.name}util-blob"
    }
  }
}
