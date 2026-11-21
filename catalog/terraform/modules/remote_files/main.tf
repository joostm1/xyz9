# remote_files — stage files, archive as tar.gz, extract onto a remote host over SSH.
variable "name" {
  type        = string
  description = "Instance name used for local archive path under path.root/.generated/remote_files/."
}
variable "connection" {
  type = object({
    host        = string
    user        = string
    password    = optional(string)
    private_key = optional(string)
    timeout     = optional(string, "5m")
  })
  description = "SSH connection for file upload and extract."
}
variable "remote_root" {
  type        = string
  description = "Absolute directory on the remote host where relative file paths are extracted."
}
variable "files" {
  type = map(object({
    content = optional(string)
    source  = optional(string)
    mode    = string
  }))
  description = "Map of remote-relative paths to file payloads. Each entry needs content or source and an octal mode."
  validation {
    condition = alltrue([
      for path, f in var.files :
      (f.content != null && f.source == null) || (f.content == null && f.source != null)
    ])
    error_message = "Each files entry must set exactly one of content or source."
  }
  validation {
    condition = alltrue([
      for path, f in var.files : can(regex("^0[0-7]{3}$", f.mode))
    ])
    error_message = "Each files entry mode must be a 4-digit octal string such as 0644."
  }
}
variable "directories" {
  type = map(object({
    mode = string
  }))
  description = "Relative dirs to create under remote_root. Every parent of a files path must be listed. Do not list remote_root or '.'."
  validation {
    condition = alltrue([
      for path, d in var.directories : can(regex("^0[0-7]{3}$", d.mode))
    ])
    error_message = "Each directories entry mode must be a 4-digit octal string such as 0755."
  }
}
variable "owner" {
  type        = string
  default     = null
  description = "Remote file owner. Defaults to connection.user."
}
variable "group" {
  type        = string
  default     = null
  description = "Remote file group. Defaults to connection.user."
}
variable "sudo" {
  type        = bool
  default     = false
  description = "Prefix extract, chmod, chown, and remote_commands with sudo -n."
}
variable "pre_commands" {
  type        = list(string)
  default     = []
  description = "Commands to run before extract. Prefixed with sudo -n when sudo is true."
}
variable "remote_commands" {
  type        = list(string)
  default     = []
  description = "Commands to run after extract. Prefixed with sudo -n when sudo is true."
}
variable "triggers_replace" {
  type        = any
  default     = null
  description = "Extra value that replaces the install resource so provisioners re-run (e.g. VM id)."
}
locals {
  conn_user    = try(nonsensitive(var.connection.user), var.connection.user)
  owner        = coalesce(var.owner, local.conn_user)
  group        = coalesce(var.group, local.conn_user)
  sudo         = var.sudo ? "sudo -n " : ""
  archive_path = "${path.root}/.generated/remote_files/${var.name}.tar.gz"
  files = {
    for path, f in var.files : path => {
      mode    = f.mode
      content = f.content != null ? f.content : file(f.source)
    }
  }
  file_paths = try(nonsensitive(sort(keys(var.files))), sort(keys(var.files)))
  file_modes = try(nonsensitive({
    for path, f in var.files : path => f.mode
    }), {
    for path, f in var.files : path => f.mode
  })
  dir_paths = try(nonsensitive(sort(keys(var.directories))), sort(keys(var.directories)))
  dir_modes = try(nonsensitive({
    for path, d in var.directories : path => d.mode
    }), {
    for path, d in var.directories : path => d.mode
  })
  required_dirs = distinct(flatten([
    for path in local.file_paths : [
      for i in range(1, length(split("/", path))) :
      join("/", slice(split("/", path), 0, i))
    ]
  ]))
  mkdir_cmds = [
    for path in local.dir_paths :
    "${local.sudo}mkdir -p '${var.remote_root}/${path}'"
  ]
  chmod_dir_cmds = [
    for path in local.dir_paths :
    "${local.sudo}chmod ${local.dir_modes[path]} '${var.remote_root}/${path}'"
  ]
  chmod_file_cmds = [
    for path, mode in local.file_modes :
    "${local.sudo}chmod ${mode} '${var.remote_root}/${path}'"
  ]
  chown_cmds = [
    for path in concat(local.dir_paths, local.file_paths) :
    "${local.sudo}chown ${local.owner}:${local.group} '${var.remote_root}/${path}'"
  ]
  post_cmds   = [for cmd in var.remote_commands : "${local.sudo}${cmd}"]
  pre_cmds    = [for cmd in var.pre_commands : "${local.sudo}${cmd}"]
  archive_sha = try(nonsensitive(data.archive_file.bundle.output_sha), data.archive_file.bundle.output_sha)
}
data "archive_file" "bundle" {
  type             = "tar.gz"
  output_path      = local.archive_path
  output_file_mode = "0644" # archive defaults to 000; extract then fails for non-root
  dynamic "source" {
    for_each = local.files
    content {
      content  = source.value.content
      filename = source.key
    }
  }
}
resource "terraform_data" "install" {
  input = {
    archive_sha     = local.archive_sha
    remote_root     = var.remote_root
    modes           = local.file_modes
    dir_modes       = local.dir_modes
    sudo            = var.sudo
    pre_commands    = var.pre_commands
    remote_commands = var.remote_commands
  }
  # Provisioners run only on create; replace when the archive or caller trigger changes.
  triggers_replace = {
    archive_sha = local.archive_sha
    extra       = var.triggers_replace
    modes       = local.file_modes
    dir_modes   = local.dir_modes
  }
  lifecycle {
    precondition {
      condition     = alltrue([for p in keys(var.directories) : p != "." && !startswith(p, "/")])
      error_message = "directories keys must be relative paths under remote_root, not '.' or an absolute path."
    }
    precondition {
      condition     = length(setsubtract(toset(local.required_dirs), toset(keys(var.directories)))) == 0
      error_message = "directories must include every parent path of files."
    }
  }
  # Callers often pass tls_private_key / cert PEMs; those stay sensitive at
  # source, but a sensitive connection or file provisioner hides remote-exec.
  connection {
    type        = "ssh"
    host        = try(nonsensitive(var.connection.host), var.connection.host)
    user        = try(nonsensitive(var.connection.user), var.connection.user)
    password    = try(nonsensitive(var.connection.password), var.connection.password)
    private_key = try(nonsensitive(var.connection.private_key), var.connection.private_key)
    timeout     = try(nonsensitive(var.connection.timeout), var.connection.timeout)
  }
  provisioner "file" {
    source      = try(nonsensitive(data.archive_file.bundle.output_path), data.archive_file.bundle.output_path)
    destination = "/tmp/remote_files_${var.name}.tar.gz"
  }
  provisioner "remote-exec" {
    inline = [
      join("\n", concat(
        [
          "set -eu",
          "archive='/tmp/remote_files_${var.name}.tar.gz'",
          "remote_root='${var.remote_root}'",
          "trap 'rm -f \"$archive\"' EXIT",
        ],
        local.pre_cmds,
        [
          "${local.sudo}mkdir -p \"$remote_root\"",
        ],
        local.mkdir_cmds,
        local.chmod_dir_cmds,
        [
          "${local.sudo}tar -xzf \"$archive\" -C \"$remote_root\"",
        ],
        local.chmod_file_cmds,
        local.chown_cmds,
        local.post_cmds,
      ))
    ]
  }
}
output "archive_sha" {
  value       = local.archive_sha
  description = "SHA of the uploaded archive; changes when any file payload changes."
}
output "remote_root" {
  value       = var.remote_root
  description = "Remote destination root."
}
output "file_paths" {
  value       = local.file_paths
  description = "Relative paths installed under remote_root."
}
terraform {
  required_providers {
    archive = {
      source = "hashicorp/archive"
    }
  }
}
