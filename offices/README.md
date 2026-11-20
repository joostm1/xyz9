# xyz9sp1

Resources for the location `sp1`, located in Stratusplein 1 de Bilt

Resources here are an orangepi w. some apps [ahem, homeassistant] and an edgerouter

## Resource workflow

`resources/aa-ca` keeps the org CA (`xyz9-ca`). `resources/aa-config` is DNS for `sp1`, the Let's Encrypt account, and the `egx` certificate. EdgeRouter configuration is not managed in this repository. State is container `offices`, keys `aa-ca.tfstate` and `aa-config.tfstate`.

```sh
cd resources/aa-config
make validate
make plan
make apply
```

The app catalog is `org/projects/homeapps.json`. Static compose files stay in `org/projects/offices/sp1/docker/`. App certificates, TLS install, compose, and backup are the `homeapps` repo. `aa-acme` reads the Let's Encrypt account key from this repo's `aa-config` state.

Or orchestrate all resource root modules from `resources/`:

```sh
cd resources
make validate
```

## Assets

Files under `resources/aa-config/assets` are not deployed by Terraform.
