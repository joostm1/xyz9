# remote_files

Stage a map of files, pack them with `hashicorp/archive` as `tar.gz`, upload once over SSH, and extract under a remote root.

Replaces ad-hoc `remote-exec` / `file` provisioner loops for small file sets (certs, host secrets). Prefer rsync for large trees that need `--delete` and exclude patterns.

## Inputs

| Name              | Description                                                       |
| ----------------- | ----------------------------------------------------------------- |
| `name`            | Local archive basename under `path.root/.generated/remote_files/` |
| `connection`      | SSH `host`, `user`, and `password` or `private_key`               |
| `remote_root`     | Absolute remote directory                                         |
| `files`           | Map of relative path → `{ content \| source, mode }`              |
| `owner` / `group` | Optional; default `connection.user`                               |
| `sudo`            | Optional; prefix extract/chmod/chown/pre_commands/remote_commands with `sudo -n` |
| `pre_commands`    | Optional; commands before extract (e.g. `cloud-init status --wait`) |
| `remote_commands` | Optional; commands after extract (e.g. `ipsec restart`)           |
| `triggers_replace`| Optional; extra replacement trigger (e.g. VM id)                  |

Each `files` entry must set exactly one of `content` or `source`.

## Example

```hcl
module "opi_tls" {
  source      = "../../org/terraform/modules/remote_files"
  name        = "opi-tls"
  remote_root = "/home/joost/tls"
  connection = {
    host     = "opi-private.example.net"
    user     = "joost"
    password = var.opi_password
  }
  files = {
    "ha/fullchain.pem" = { content = var.ha_cert_pem, mode = "0644" }
    "ha/privkey.pem"   = { content = var.ha_key_pem, mode = "0600" }
  }
}
```

## Behaviour

1. Build archive at plan/apply via `data.archive_file` (`tar.gz`, `output_file_mode = "0644"` so entries are not mode `000`)
2. SCP archive to `/tmp`
3. Extract with `tar -xzf … -C remote_root`
4. `chmod` / `chown` each installed path
5. Run `remote_commands` when set

Change detection uses `triggers_replace` (archive SHA plus optional caller trigger such as a VM id). Provisioners run only when the `terraform_data` resource is created, so those values must replace it rather than sit in `input`.

The SSH `connection` and archive path are passed through `nonsensitive()` so `remote-exec` stdout is visible. Caller values (e.g. `tls_private_key`) remain sensitive in their own resources; they still land in state and in `.generated/remote_files/*.tar.gz`.
