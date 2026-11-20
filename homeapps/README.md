# homeapps

Offsite copy of OPI state that is not already in git or Key Vault.

The catalog is `org/projects/homeapps.json`. `resources/aa-acme` issues the app host certificates and installs their PEMs. `resources/aa-apps` applies compose and host secrets. `resources/ba-docker-data` runs the backup. DNS, the Let's Encrypt account, and the org CA (`xyz9-ca`) are the offices repo.

```sh
cd resources
make validate
make plan
make apply
```

`aa-acme` uses `project_name` `homeapps`. Certificate objects are `${project_name}-<host>-cert`. State is container `homeapps`, keys `aa-acme.tfstate`, `aa-apps.tfstate`, and `ba-docker-data.tfstate`. See `resources/ba-docker-data/README.md`.
