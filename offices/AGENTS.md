# xyz9sp1 agent instructions

Read [`org/AGENTS.md`](org/AGENTS.md) first for shared rules.

## This repository

- Project catalog: `org/projects/offices.json` (`offices.sp1` network). App catalog: `org/projects/homeapps.json`
- Submodule: `org` (`xyz9cf`) — commit to `org` before `offices`
- Root modules: `resources/aa-ca` (org CA `xyz9-ca`), `resources/aa-config` (DNS, Let's Encrypt account, `egx` certificate). Apply via `resources/Makefile`. State container `offices`, keys `aa-ca.tfstate` and `aa-config.tfstate`. Key Vault certificate object name is `org/org.json` `about.x509.ca.vault_name`
- Static Docker files: `org/projects/offices/sp1/docker/`. App certificates, OPI TLS install, and compose: `homeapps` `resources/aa-acme` then `resources/aa-apps`
- OPI data backup: `homeapps` `resources/ba-docker-data`
- Monthly apply: `azure-pipelines.yml` on Microsoft-hosted Azure Pipelines. Build definition `xyz9sp1-apply` is owned by `resources/aa-config` (`pipeline.tf`)
