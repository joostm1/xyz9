# Handoff

## Current Objective

Operate `xyz9sp1` as the Stratusplein 1 (`sp1`) landing zone: DNS, certificates, passive router/VM assets, and Docker workloads on OPI (Orange Pi), driven from org project JSON rather than Ansible.

Primary context lives in:

- `org/xyz9.json`
- `org/projects/offices.json` (`offices.sp1`)

Re-read both at the start of a new session.

## Applied Docker Shape

Docker on OPI is fully Terraform-managed via `resources/aa-config/main.tf` and `kreuzwerker/docker` over SSH.

Configuration flow:

```text
org/projects/offices.json          offices.sp1.applications.docker (host, services, host_secrets, data_directories)
org/projects/offices/sp1/docker/   static config (rsync to OPI config_root)
resources/aa-config/secrets/opi/   controller-side host secrets (gitignored)
resources/aa-config/.generated/    rendered compose JSON (gitignored)
```

Each enabled service with `manage_compose: true` carries an inline `compose` object in project JSON (no per-service `docker-compose.yml` in org for managed services).

Volume bind paths use placeholders resolved at apply time from `docker.host`:

```text
$config_root  -> /home/joost/docker/config
$data_root    -> /home/joost/docker/data
$tls_root     -> /home/joost/tls
```

Compose env vars such as `${POSTGRES_PASSWORD}` are left untouched.

### `map_join` catalogs

All `for_each` loops iterate over `module.*.by_key` (xyz9df `warehouse_dataset_matrix` cross-join pattern, `join_key = "all"`):

| Module                    | Join                               | Purpose                                |
| ------------------------- | ---------------------------------- | -------------------------------------- |
| `docker_compose_services` | services × `docker.host`           | compose lifecycle                      |
| `docker_host_secrets`     | `host_secrets` × `docker.host`     | secret dest = `${config_root}/${dest}` |
| `docker_data_directories` | `data_directories` × `docker.host` | mkdir paths = `${data_root}/${path}`   |

### Managed services (current catalog)

Seven compose-managed services in `docker.services`:

```text
homeassistant, mailserver, nginx, postgres, unifi, unifi-protect, vaultwarden
```

Removed from catalog:

```text
azuresqledge, mssql, mqtt5, ring-mqtt
```

Set `"manage_compose": false` on a service to rsync static config only, without managing its compose project.

## Ansible Cutover

Production path is Terraform only. Feature flags (`docker_config_enabled`, `docker_compose_enabled`) were removed; Docker is always managed when `homeapps` `aa-apps` is applied.

Legacy folders still in the tree but not wired into current `main.tf`:

```text
resources/aa-config/ansible/
resources/aa-config/docker-config/
```

Safe to delete once you confirm nothing still references them.

State migration (only if plan reports moved singleton resources):

```sh
terraform state mv 'terraform_data.docker_files[0]' 'terraform_data.docker_files' 2>/dev/null || true
terraform state mv 'terraform_data.require_host_secrets[0]' 'terraform_data.require_host_secrets' 2>/dev/null || true
```

Cutover apply succeeded; running stacks on OPI include mailserver, homeassistant, unifi, postgres, vaultwarden, nginx (and others per catalog above).

## Host Secrets

Whole secret-file bodies in corp Key Vault (`docker.host_secrets.vault_secret`). Terraform materializes `.generated/secrets/` for Compose `env_files` and installs onto OPI via `remote_files`.

```text
xyz9sp1-opi-postgres-env
xyz9sp1-opi-vaultwarden-env
xyz9sp1-opi-mailserver-accounts
```

Local `secrets/opi/` is no longer required. Seed vault with `az keyvault secret set --file …` (see `resources/aa-config/secrets/README.md`).

## Data Backup Policy

`docker.data_directories` plus `docker.backup` in the project JSON. The `homeapps` repo (`resources/ba-docker-data`) installs `/home/joost/docker/backup` and `opi-backup.timer` (03:30 UTC). Required directories upload to container `xyz9sp1-opi` on `xz9saiac`. `xyz9sp1-owners` can read that container. The old `bw-export` timer and its SAS URL are retired; container `vaultwarden-backups` still holds the earlier JSON exports.

## Resource Modules

Lexical apply order via `resources/Makefile`:

```text
aa-ca          org CA xyz9-ca, state key aa-ca.tfstate
aa-config      DNS, app certs, OPI TLS install
homeapps       aa-apps compose, ba-docker-data backup, state container homeapps
```

Passive config under `resources/aa-config/assets/` (er6p, opi, vmcfg) is not deployed by Terraform.

## Applied Checks

Recent checks in `resources/aa-config`:

```sh
make validate
terraform validate
```

Both succeeded after `map_join` refactor and inline compose JSON migration.

Full destroy + apply cycle completed cleanly once: `Resources: 69 added, 0 changed, 0 destroyed.`
OPI backup before that cycle: `/root/docker.tar` (`tar cf ~/docker.tar docker tls` from `/home/joost`; postfix socket warnings are expected).

## Caution Points

- Docker provider talks to OPI over SSH; local `docker` CLI is not required on the controller
- `local_file.docker_compose_config` writes controller-side JSON; `docker_compose` uses those paths while `project_directory` on OPI is `${config_root}/<service>`
- Rsync excludes `.env` and `mailserver/config/` from git-managed tree; host secrets are copied separately
- For Terraform plan/apply failures, stop after analyzing the failure and propose a fix
- `org` is a submodule; commit changes in `org` before committing the parent repo so the parent records the correct subproject commit
- `org/AGENTS.md` holds shared agent rules; repo-root `AGENTS.md` is the xyz9sp1 entry point
- Cert and host-secret installs use `org/terraform/modules/remote_files` (`tar.gz` + SSH extract). Docker static config still uses rsync. UniFi keystore import deferred; `egx` excluded from OPI TLS install
- **Let's Encrypt rate limits:** a full `aa-config` destroy re-issues all `sp1_hosts` certs on the next apply. Prefer targeted Docker-only destroys when certs/DNS are fine

## Next session: move Docker/TLS to `/`

Deferred deliberately after LE rate-limit risk. Goal: paths under `/docker` and `/tls` instead of `/home/joost/...`.

### Order of operations

1. Confirm LE is safe to re-issue (or avoid full destroy — see below)
2. Update `org/projects/offices.json` `offices.sp1.applications.docker.host`:
   - `config_root` → `/docker/config`
   - `data_root` → `/docker/data`
   - `tls_root` → `/tls`
   - Fix any leftover absolute path notes under `data_directories`
3. ~~Update cert installers for `tls_root`~~ — done (`module.opi_tls_files` via `remote_files`)
4. On OPI (as root, then fix ownership for Terraform user `joost`):
   ```sh
   mv /home/joost/docker /docker
   mv /home/joost/tls /tls
   chown -R joost:joost /docker /tls
   ```
5. Prefer **not** another full `make destroy` if DNS/certs are healthy — only recreate Docker resources, or plan/apply after path changes so Terraform updates in place. If a full destroy is still desired, wait until LE quotas allow
6. `make plan` / `make apply` from `resources/aa-config`
7. Verify containers mount `/docker/...` and `/tls/...`, and that cert provisioners wrote PEMs under `/tls/<host>/`

### Why main.tf already follows tls_root

`module.opi_tls_files` (`remote_files`) writes `${docker.host.tls_root}/<host>/{fullchain,privkey}.pem`. Changing JSON `tls_root` is enough for cert install after the path move; compose `$tls_root` mounts resolve the same way.

## Suggested Next Session Start

Run/read:

```sh
git status --short
git diff --stat
```

Then inspect:

- `org/AGENTS.md`
- `AGENTS.md`
- `HANDOFF.md` (section **Next session: move Docker/TLS to `/`**)
- `org/projects/offices.json` (`offices.sp1.applications.docker.host`)
- `resources/aa-config/main.tf` (cert install provisioners)
- `resources/aa-config/main.tf`
