# OPI host secrets

Whole secret **file** bodies are stored in the corporate Azure Key Vault. Terraform reads them at plan time and:

1. Writes controller copies under `.generated/secrets/` for Compose `env_files`
2. Installs the same content on OPI under `docker.host.config_root` via `remote_files`

Catalog: `org/projects/offices.json` → `offices.sp1.applications.docker.host_secrets`:

| Key                   | Key Vault secret name             | OPI dest                                |
| --------------------- | --------------------------------- | --------------------------------------- |
| `postgres_env`        | `xyz9sp1-opi-postgres-env`        | `postgres/.env`                         |
| `vaultwarden_env`     | `xyz9sp1-opi-vaultwarden-env`     | `vaultwarden/.env`                      |
| `mailserver_accounts` | `xyz9sp1-opi-mailserver-accounts` | `mailserver/config/postfix-accounts.cf` |

Seed or rotate (example):

```sh
az keyvault secret set --vault-name xz9kviac --name xyz9sp1-opi-postgres-env --file postgres.env
az keyvault secret set --vault-name xz9kviac --name xyz9sp1-opi-vaultwarden-env --file vaultwarden.env
az keyvault secret set --vault-name xz9kviac --name xyz9sp1-opi-mailserver-accounts --file postfix-accounts.cf
```

Vault name comes from `corp_vault_id` (…/vaults/`<name>`). Values are the full file contents (including newlines).

Legacy `secrets/opi/` is removed on apply by `terraform_data.remove_local_opi_secrets` once vault-backed install has succeeded. Do not keep working copies there.

TLS PEMs are installed by `main.tf` / `remote_files` from ACME, not from these secrets.
