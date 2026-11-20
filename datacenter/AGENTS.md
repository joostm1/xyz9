# Agent Instructions For datacenter

Local supplement to `org/AGENTS.md`; org guidance wins on conflict.

`datacenter` is the XYZ9 Data Center project:
It provide azure hub/spoke connectivity for other XYZ9 projects

## Shape

```text
org/                 # xyz9cf submodule: org config, schemas, shared modules
resources/aa-config  # foundation: RG, KV, Entra groups, DNS zones
resources/ba-hubs    # hub VNets, NVAs, VPN mesh, DNS
resources/bb-offices # office EdgeRouter IPsec mesh files
resources/ca-spokes  # spoke VNets and projects.datacenter contributions
resources/shared     # ipsec_mesh / mesh_members used by ba-hubs and bb-offices
scripts/             # VM/host provisioning
assets/              # static assets
```

## Root Modules

Run lifecycle order is alphabetical: `aa-config`, `ba-hubs`, `bb-offices`, `ca-spokes`.

Same-project roots read predecessor `output.config` via `terraform_remote_state`, merge under `roots[var.state_key]`, and emit the full `output "config"`.

`ca-spokes` also crosses project boundaries: it reads spoke `${projectName}-config` secrets from the corporate Key Vault and merges this project's contribution under `projects.datacenter` without dropping existing keys.

`var.state_key` must match the root module folder name.

## Data

`org/projects/datacenter.json` defines this project's Azure settings, credentials, scopes, roles, and hub locations. Office sites are `org/projects/offices.json` `offices`; sp1 (stratusplein 1) is the only office.

Inspect `org/schemas/projects.schema.json` before editing project seeds. Projects with `hub_location` are spoke candidates, and the value must be a schema-allowed datacenter location.

`offices` join the hub IPsec mesh. `router` is a DNS label (`egx`); datacenter generates StrongSwan files and installs them on the office router via `org/terraform/modules/remote_files`.

Runtime contributions belong in Key Vault or Terraform outputs, not in `org/projects/*.json`.
