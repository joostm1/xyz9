# aa-acme

Let's Encrypt certificates for the OPI app hosts (`ha`, `mx1`, `unifi`, `vault`) and the PEM files compose mounts.

The Let's Encrypt account stays in offices `resources/aa-config`, with DNS and the `egx` certificate. This root reads that account key from offices state `aa-config.tfstate`. Certificate object names are `${var.project_name}-<host>-cert`.

`project_name` is `homeapps`, so the root reads `homeapps-config`. State is container `homeapps`, key `aa-acme.tfstate`. Apply this root before `aa-apps`.
