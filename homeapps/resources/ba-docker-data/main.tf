data "azurerm_key_vault_secret" "sp1_secrets" {
  for_each     = toset(["nvaAdminUserName", "adminPK"])
  name         = each.key
  key_vault_id = var.corp_vault_id
  provider     = azurerm.corp # xz9saiac is not in the project subscription
}
data "azurerm_key_vault_secret" "vaultwarden_export" {
  for_each     = local.backup.vaultwarden_export.secrets
  name         = each.value
  key_vault_id = var.corp_vault_id
  provider     = azurerm.corp
}
data "azurerm_storage_account" "backup" {
  name                = local.backup.account
  resource_group_name = var.resource_group_name
  provider            = azurerm.corp
}
data "azuread_client_config" "current" {}
data "azuread_group" "owners" {
  display_name     = "${var.project_name}-owners"
  security_enabled = true
}
# Writer for OPI only. The project owner app can read Key Vault and the state container; this app cannot.
resource "azuread_application" "writer" {
  display_name            = "${var.project_name}-opi-backup"
  owners                  = [data.azuread_client_config.current.object_id]
  sign_in_audience        = "AzureADMyOrg"
  prevent_duplicate_names = true
}
resource "azuread_service_principal" "writer" {
  client_id = azuread_application.writer.client_id
  owners    = [data.azuread_client_config.current.object_id]
}
resource "tls_private_key" "writer" {
  algorithm = "RSA"
  rsa_bits  = 2048
}
resource "tls_self_signed_cert" "writer" {
  private_key_pem       = tls_private_key.writer.private_key_pem
  validity_period_hours = 365 * 24
  early_renewal_hours   = 30 * 24
  subject {
    organization = local.org.about.x509.org
    common_name  = "${var.project_name}-opi-backup"
  }
  allowed_uses = [
    "digital_signature",
    "key_encipherment",
    "client_auth",
  ]
}
resource "random_password" "writer" {
  length  = 32
  special = false
}
resource "pkcs12_from_pem" "writer" {
  cert_pem        = tls_self_signed_cert.writer.cert_pem
  private_key_pem = tls_private_key.writer.private_key_pem
  password        = random_password.writer.result
  encoding        = "legacyDES" # azcopy's Go pkcs12 parser rejects the modern SHA-256 bag
}
resource "azuread_application_certificate" "writer" {
  application_id = azuread_application.writer.id
  type           = "AsymmetricX509Cert"
  encoding       = "pem"
  value          = tls_self_signed_cert.writer.cert_pem
  end_date       = tls_self_signed_cert.writer.validity_end_time
  lifecycle {
    ignore_changes = [end_date]
  }
}
resource "azurerm_storage_container" "opi" {
  name                  = local.backup.container
  storage_account_id    = data.azurerm_storage_account.backup.id
  container_access_type = "private"
  provider              = azurerm.corp
}
resource "azurerm_role_assignment" "writer" {
  provider                         = azurerm.corp
  scope                            = azurerm_storage_container.opi.id
  role_definition_name             = "Storage Blob Data Contributor"
  principal_id                     = azuread_service_principal.writer.object_id
  principal_type                   = "ServicePrincipal"
  skip_service_principal_aad_check = true
  description                      = "OPI backup writer uploads to ${azurerm_storage_container.opi.name} only"
}
resource "azurerm_role_assignment" "owners" {
  provider             = azurerm.corp
  scope                = azurerm_storage_container.opi.id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = data.azuread_group.owners.object_id
  principal_type       = "Group"
  description          = "${var.project_name} owners can restore OPI backups without the writer certificate"
}
locals {
  opi_ssh = {
    host     = "${local.docker.host.dns_name}.${local.org.about.dns_domain}"
    user     = data.azurerm_key_vault_secret.sp1_secrets["nvaAdminUserName"].value
    password = data.azurerm_key_vault_secret.sp1_secrets["adminPK"].value
  }
  manifest = {
    account        = local.backup.account
    container      = local.backup.container
    tenant_id      = var.tenant_id
    client_id      = azuread_application.writer.client_id
    retain_days    = local.backup.retain_days
    azcopy_version = local.backup.azcopy_version
    vaultwarden_export = {
      server               = local.backup.vaultwarden_export.server
      client_id_file       = local.secret_files.client_id
      client_secret_file   = local.secret_files.client_secret
      master_password_file = local.secret_files.master_password
      export_password_file = local.secret_files.export_password
    }
    targets = [
      for name in sort(keys(local.backup_targets)) : {
        name      = local.backup_targets[name].name
        method    = local.backup_targets[name].method
        path      = local.backup_targets[name].path
        exclude   = local.backup_targets[name].exclude
        container = local.backup_targets[name].container
        user      = local.backup_targets[name].user
      }
    ]
  }
}
resource "terraform_data" "backup_policy" {
  input = sort(keys(local.backup_targets))
  lifecycle {
    precondition {
      condition     = var.org_name == local.org.name
      error_message = "org_name must match org.json name."
    }
    precondition {
      condition     = var.storage_account_name == local.backup.account
      error_message = "docker.backup.account must be the corp state storage account from ~/.tfvars."
    }
    precondition {
      condition = alltrue([
        for _, dir in local.docker.data_directories :
        contains(["required", "none"], dir.backup) && contains(local.known_methods, dir.method)
      ])
      error_message = "Each data directory needs backup required or none, and a known method."
    }
    precondition {
      condition = alltrue([
        for _, target in local.backup_targets :
        target.method != "pg_dump" || (target.container != null && target.user != null)
      ])
      error_message = "A pg_dump directory needs a compose container_name and POSTGRES_USER."
    }
  }
}
module "opi_backup_files" {
  source      = "${local.org_folder}/terraform/modules/remote_files"
  name        = "opi-backup"
  remote_root = local.backup_root
  connection  = local.opi_ssh
  directories = {}
  files = merge(
    {
      "opi-backup.py" = {
        content = file("${path.module}/opi-backup.py")
        mode    = "0755"
      }
      "manifest.json" = {
        content = jsonencode(local.manifest)
        mode    = "0640"
      }
      "writer.pfx.b64" = {
        content = sensitive(pkcs12_from_pem.writer.result)
        mode    = "0600"
      }
      "writer.pfx.pass" = {
        content = random_password.writer.result
        mode    = "0600"
      }
    },
    {
      for key, filename in local.secret_files : filename => {
        content = data.azurerm_key_vault_secret.vaultwarden_export[key].value
        mode    = "0600"
      }
    }
  )
  depends_on = [
    azurerm_role_assignment.writer,
    azurerm_role_assignment.owners,
    azuread_application_certificate.writer,
    terraform_data.backup_policy,
  ]
}
module "opi_backup_units" {
  source      = "${local.org_folder}/terraform/modules/remote_files"
  name        = "opi-backup-systemd"
  remote_root = "/etc/systemd/system"
  connection  = local.opi_ssh
  sudo        = true
  owner       = "root"
  group       = "root"
  directories = {}
  files = {
    "opi-backup.service" = {
      content = templatefile("${path.module}/opi-backup.service.tftpl", {
        account = local.backup.account
        script  = "${local.backup_root}/opi-backup.py"
      })
      mode = "0644"
    }
    "opi-backup.timer" = {
      content = templatefile("${path.module}/opi-backup.timer.tftpl", {
        schedule = local.backup.schedule
      })
      mode = "0644"
    }
  }
  remote_commands = [
    "systemctl disable --now bw-export.timer bw-export.service || true",
    "rm -f /etc/systemd/system/bw-export.service /etc/systemd/system/bw-export.timer",
    "systemctl daemon-reload",
    "systemctl enable --now opi-backup.timer",
  ]
  depends_on = [module.opi_backup_files]
}
output "backup_container_url" {
  value = "https://${local.backup.account}.blob.core.windows.net/${azurerm_storage_container.opi.name}"
}
output "backup_writer_client_id" {
  value = azuread_application.writer.client_id
}
output "backup_targets" {
  value = [for target in local.manifest.targets : "${target.name} ${target.method} ${target.path}"]
}
