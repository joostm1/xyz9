# ba-docker-data

Daily offsite copy of OPI state that is not already in git or Key Vault.

`org/projects/offices.json` (`offices.sp1.applications.docker`) is the catalog:

- `docker.data_directories` says what is required and which method to use
- `docker.backup` says where it goes: storage account `xz9saiac`, container `homeapps-opi`, 03:30 UTC, 30 days

`nginx` is `backup: none` and is skipped. UniFi uploads `data/backup` only.

The job runs on OPI as root (`opi-backup.timer`) so it can read mail. It authenticates with a certificate for app `homeapps-opi-backup`, which can write only this container. `homeapps-owners` (joost@xyz9.net) can read it back with `azcopy` after `az login`. No storage account key and no SAS.

Layout:

```text
vaultwarden/YYYY-MM-DD.json     Bitwarden encrypted export
vaultwarden/YYYY-MM-DD.tar.gz   consistent sqlite plus attachments
postgres/YYYY-MM-DD.sql.gz      pg_dumpall
mailserver/YYYY-MM-DD.tar.gz
unifi/YYYY-MM-DD.tar.gz         controller autobackup
homeassistant/YYYY-MM-DD.tar.gz
status/YYYY-MM-DD.json
```

Restore a postgres dump with `gzip -dc postgres.sql.gz | docker exec -i postgres psql -U 'postgres@xyz9.net'`. Import the vaultwarden JSON with `bw import` using Key Vault secret `homeapps-opi-vaultwarden-bw-export-password`. Older JSON exports remain in container `vaultwarden-backups`.

Files live in `/home/joost/docker/backup`, next to `config/` and `data/`. `aa-apps` rsyncs only `config/` with `--delete`, so this directory survives an apply.

```sh
cd resources/ba-docker-data
make plan
make apply
```
