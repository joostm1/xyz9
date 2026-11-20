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
  org_folder = "../../org"
  org        = jsondecode(file("${local.org_folder}/org.json"))
  project    = jsondecode(file("${local.org_folder}/projects/homeapps.json"))
  docker     = local.project.applications.docker
  config     = jsondecode(data.azurerm_key_vault_secret.config_init.value)

  # OPI Docker config and compose lifecycle (kreuzwerker/docker).
  # Service catalog: org/projects/homeapps.json → applications.docker
  docker_project_root   = "${local.org_folder}/projects/offices/sp1"
  docker_host           = merge(local.docker.host, { join_key = "all" })
  docker_rsync_excludes = local.docker.rsync_excludes
  docker_assets_hash = sha256(join("", [
    for f in sort(fileset("${local.docker_project_root}/docker", "**")) :
    filesha256("${local.docker_project_root}/docker/${f}")
  ]))
  docker_data_dir_paths = [
    for _key, entry in module.docker_data_directories.by_key :
    "${entry.data_root}/${entry.path}"
  ]
  docker_compose_resolved = {
    for key, entry in module.docker_compose_services.by_key :
    key => jsondecode(replace(replace(replace(
      jsonencode(entry.compose),
      "$config_root", entry.config_root,
    ), "$data_root", entry.data_root), "$tls_root", entry.tls_root))
  }
  docker_compose_hash = sha256(jsonencode(local.docker_compose_resolved))
  # Relative names under .generated/compose. Content is the resolved compose object.
  docker_compose_files = {
    for key, doc in local.docker_compose_resolved :
    "${key}.json" => jsonencode(doc)
  }
  docker_compose_env_dests = toset(flatten([
    for svc in values(module.docker_compose_services.by_key) : try(svc.env_files, [])
  ]))
  # dest -> vault secret name. Only files listed in env_files; docker_compose hashes those at plan time.
  docker_compose_secret_names = {
    for dest, entry in local.docker_host_secrets_by_dest : dest => entry.vault_secret
    if contains(local.docker_compose_env_dests, dest)
  }
  opi_host     = "${local.docker.host.dns_name}.${local.org.about.dns_domain}"
  opi_user     = local.docker.host.user
  opi_password = data.azurerm_key_vault_secret.sp1_secrets["adminPK"].value
  opi_ssh = {
    host     = local.opi_host
    user     = local.opi_user
    password = local.opi_password
  }
  docker_host_secrets_by_dest = {
    for key, secret in local.docker.host_secrets : secret.dest => merge(secret, {
      secret_key = key
    })
  }
  # postgres/.env -> postgres; mailserver/config/postfix-accounts.cf -> mailserver, mailserver/config
  opi_host_secret_directories = {
    for dir in distinct(flatten([
      for dest in keys(local.docker_host_secrets_by_dest) : [
        for i in range(1, length(split("/", dest))) :
        join("/", slice(split("/", dest), 0, i))
      ]
    ])) : dir => { mode = "0755" }
  }
}
