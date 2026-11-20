# aa-config

Root Terraform module for the `sp1` location: DNS, the Let's Encrypt account, and the `egx` certificate. The org CA is `resources/aa-ca`. App host certificates and the OPI TLS install are `homeapps` `resources/aa-acme`. EdgeRouter configuration is not managed here.

## Pipeline

`pipeline.tf` adopts Azure DevOps build definition `xyz9sp1-apply` in project `xyz9it` and sets the pipeline variables that `azure-pipelines.yml` writes to `~/.tfbackend.hcl` (`resource_group_name`, `storage_account_name`, `subscription_id`, `tenant_id`) and `~/.tfvars` (`corp_vault_id` plus the same names except `subscription_id`). The monthly cron stays in the YAML. The job runs on Microsoft-hosted `ubuntu-latest`.

## Terraform workflow

```sh
cd resources/aa-config
make validate
make plan
make apply
```

`aa-acme` in homeapps issues the `ha`, `mx1`, `unifi`, and `vault` certificates with the account key from output `acme_account_key_pem`. Compose, host secrets, and backup are applied from that repo. The catalog is `org/projects/homeapps.json`. Static compose files stay under `org/projects/offices/sp1/docker/`.

Files under `assets/` (er6p, opi, vmcfg) are not deployed.
