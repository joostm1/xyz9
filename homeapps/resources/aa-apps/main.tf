data "azurerm_key_vault_secret" "config_init" {
  name         = "${var.project_name}-config"
  key_vault_id = var.corp_vault_id
  provider     = azurerm.corp
}
data "azurerm_key_vault_secret" "owner_p12" {
  name         = "${var.project_name}-owner-p12"
  key_vault_id = var.corp_vault_id
  provider     = azurerm.corp
}
data "azurerm_key_vault_secret" "sp1_secrets" {
  for_each = toset([
    "cloudflare-dns-editzonekey",
    "nvaAdminUserName",
    "adminPK",
  ])
  name         = each.key
  key_vault_id = var.corp_vault_id
  provider     = azurerm.corp
}

# Cross-join each compose-managed service with docker.host
module "docker_compose_services" {
  source = "${local.org_folder}/terraform/modules/map_join"
  left = {
    for name, svc in local.docker.services : name => merge(svc, {
      service_key = name
      join_key    = "all"
    }) if try(svc.enabled, true) && try(svc.manage_compose, false)
  }
  right = {
    host = local.docker_host
  }
  left_match_attr  = "join_key"
  right_match_attr = "join_key"
  key_attrs        = ["service_key"]
}
module "docker_data_directories" {
  source = "${local.org_folder}/terraform/modules/map_join"
  left = {
    for name, dir in local.docker.data_directories : name => merge(dir, {
      directory_key = name
      join_key      = "all"
    })
  }
  right = {
    host = local.docker_host
  }
  left_match_attr  = "join_key"
  right_match_attr = "join_key"
  key_attrs        = ["directory_key"]
}
resource "terraform_data" "docker_files" {
  input = {
    assets_hash  = local.docker_assets_hash
    compose_hash = local.docker_compose_hash
    data_dirs    = local.docker_data_dir_paths
  }
  # Provisioners run only on create. Replace so a new data dir is mkdir'd before compose starts.
  triggers_replace = {
    assets_hash = local.docker_assets_hash
    data_dirs   = local.docker_data_dir_paths
  }
  connection {
    type     = "ssh"
    host     = local.opi_host
    user     = local.opi_user
    password = local.opi_password
    timeout  = "5m"
  }
  provisioner "remote-exec" {
    inline = concat(
      [
        "mkdir -p '${local.docker.host.config_root}' '${local.docker.host.data_root}'",
      ],
      [for path in local.docker_data_dir_paths : "mkdir -p '${path}'"],
    )
  }
  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-c"]
    command     = <<-EOT
      set -euo pipefail
      excludes=(${join(" ", [for e in local.docker_rsync_excludes : format("%q", e)])})
      rsync_opts=(--archive --delete --omit-dir-times)
      for pattern in "$${excludes[@]}"; do
        rsync_opts+=(--exclude="$pattern")
      done
      rsync -e "ssh -o StrictHostKeyChecking=accept-new" "$${rsync_opts[@]}" \
        "${local.docker_project_root}/docker/" \
        "${local.opi_user}@${local.opi_host}:${local.docker.host.config_root}/"
    EOT
  }
}
# Whole secret-file bodies live in corp Key Vault (see docker.host_secrets.vault_secret).
data "azurerm_key_vault_secret" "opi_host_secrets" {
  for_each     = local.docker.host_secrets
  name         = each.value.vault_secret
  key_vault_id = var.corp_vault_id
  provider     = azurerm.corp
}
module "opi_host_secret_files" {
  source      = "${local.org_folder}/terraform/modules/remote_files"
  name        = "opi-host-secrets"
  remote_root = local.docker.host.config_root
  connection  = local.opi_ssh
  directories = local.opi_host_secret_directories
  files = {
    for dest, entry in local.docker_host_secrets_by_dest : dest => {
      content = data.azurerm_key_vault_secret.opi_host_secrets[entry.secret_key].value
      mode    = entry.mode
    }
  }
  depends_on = [terraform_data.docker_files]
}
# One-shot: drop legacy local secrets/opi after Key Vault is the source of truth.
resource "terraform_data" "remove_local_opi_secrets" {
  input = "keyvault-backed"
  depends_on = [
    data.azurerm_key_vault_secret.opi_host_secrets,
    module.opi_host_secret_files,
  ]
  provisioner "local-exec" {
    when    = create
    command = "rm -rf '${path.module}/secrets/opi'"
  }
}
# docker_compose hashes these paths during plan. .generated is not in git, so create it here rather than on apply.
data "external" "docker_compose_inputs" {
  program = ["python3", "${path.module}/write_compose_inputs.py"]
  query = {
    compose_dir = "${path.module}/.generated/compose"
    secrets_dir = "${path.module}/.generated/secrets"
    vault_name  = reverse(split("/", var.corp_vault_id))[0]
    compose     = jsonencode(local.docker_compose_files)
    secrets     = jsonencode(local.docker_compose_secret_names)
  }
}
# Forget the old apply-time copies. destroy=false so that forget does not delete the files just written above.
removed {
  from = local_file.docker_compose_config
  lifecycle {
    destroy = false
  }
}
removed {
  from = local_sensitive_file.opi_host_secrets
  lifecycle {
    destroy = false
  }
}
resource "docker_compose" "service" {
  for_each          = module.docker_compose_services.by_key
  project_name      = each.key
  project_directory = "${each.value.config_root}/${each.key}"
  remove_orphans    = true
  # result.* is the dependency: a literal path would let the hash run before the writer.
  config_paths = [
    "${data.external.docker_compose_inputs.result.compose_dir}/${each.key}.json",
  ]
  env_files = [
    for rel in try(each.value.env_files, []) :
    "${data.external.docker_compose_inputs.result.secrets_dir}/${rel}"
  ]
  depends_on = [
    terraform_data.docker_files,
    module.opi_host_secret_files,
  ]
}
output "docker_compose_services" {
  value = sort(keys(module.docker_compose_services.by_key))
}
output "docker_config_root" {
  value = local.docker.host.config_root
}
