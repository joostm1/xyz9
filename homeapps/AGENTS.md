# homeapps agent instructions

Read [`org/AGENTS.md`](org/AGENTS.md) first for shared rules.

## This repository

- OPI applications at Stratusplein 1. Catalog: `org/projects/homeapps.json` (`applications.docker`). Static files stay in `org/projects/offices/sp1/docker/`
- Submodule: `org` (`xyz9cf`) — commit to `org` before `homeapps`
- Root modules: `resources/aa-acme` (app certificates and OPI TLS install), `resources/aa-apps` (compose and host secrets), `resources/ba-docker-data` (backup). Org CA `xyz9-ca`, DNS, and the Let's Encrypt account are `offices`
- Uploads `docker.data_directories` with `backup: required` to container `docker.backup.container` on `xz9saiac`
- State container `homeapps` on `xz9saiac`, keys `aa-acme.tfstate`, `aa-apps.tfstate`, and `ba-docker-data.tfstate`
- `aa-acme` uses `project_name` `homeapps`. Certificate objects are `${project_name}-<host>-cert`. App `${project_name}-opi-backup` and group `${project_name}-owners` use the same prefix
