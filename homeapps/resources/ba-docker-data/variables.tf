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
  org_folder  = "../../org"
  org         = jsondecode(file("${local.org_folder}/org.json"))
  project     = jsondecode(file("${local.org_folder}/projects/homeapps.json"))
  docker      = local.project.applications.docker
  backup      = local.docker.backup
  backup_root = "${dirname(local.docker.host.data_root)}/backup" # sibling of config/; rsync --delete does not see it
  secret_files = {
    client_id       = "bw-clientid"
    client_secret   = "bw-clientsecret"
    master_password = "bw-master-password"
    export_password = "bw-export-password"
  }
  known_methods = toset(["file_backup", "pg_dump", "application_backup", "sqlite_file_backup", "bitwarden_encrypted_json"])
  backup_targets = {
    for name, dir in local.docker.data_directories : name => {
      name    = name
      method  = dir.method
      path    = "${local.docker.host.data_root}/${dir.path}${try(dir.source, null) == null ? "" : "/${dir.source}"}"
      exclude = try(dir.exclude, [])
      container = try(one([
        for svc in values(local.docker.services[name].compose.services) : svc.container_name
      ]), null)
      user = try(one([
        for svc in values(local.docker.services[name].compose.services) : svc.environment.POSTGRES_USER
      ]), null)
    } if dir.backup == "required"
  }
}
