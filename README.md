# xyz9

Public infrastructure-as-code repository for xyz9's hub-spoke project.

xyz9 is an imaginary company's IT department, providing shared identity, networking, landing-zone, application, and data infrastructure.

The repository brings those pieces together as a connected enterprise environment: Azure hubs provide shared network services, office sites join the hubs through an IPsec mesh, and project spokes land in the hub that serves them. The design supports extending the mesh across multiple hub locations and offices, while the current example configuration connects the `apc1` hub with the `sp1` office and a data-platform spoke. Alongside connectivity, the catalog and Terraform roots provision the shared identity, DNS, access, and workload foundations that make those environments usable.

## Apply-order groups

- `catalog/`
  - shared catalog data, schema contracts, and reusable Terraform modules
- `azhubs/`
  - hub-spoke connectivity roots (`aa-foundation`, `ba-hubs`, `bb-sp1-connectivity`, `ca-spokes`)
- `spoke-projects/`
  - projects connected to the hub
  - current example: `datafactory` with roots in apply order

The `azhubs/bb-sp1-connectivity` root manages connectivity to `sp1`.

## How to operate

Prerequisites:

- Terraform CLI
- Azure CLI auth for target tenant/subscription
- backend and variable files (`~/.tfbackend.hcl`, `~/.tfvars`)

Repository commands:

- `make list`
- `make validate`
- `make plan`
- `make apply`
- `make destroy`

Group commands (examples):

- `make -C azhubs list`
- `make -C azhubs plan`
- `make -C spoke-projects/datafactory plan`

## Documentation

- Architecture: `docs/ARCHITECTURE.md`
- Repository map: `docs/REPOSITORY_MAP.md`
- Contributing: `CONTRIBUTING.md`
- Security: `SECURITY.md`
