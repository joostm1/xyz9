# xyz9 hub-spoke stack

Public infrastructure-as-code repository for a hub-spoke platform, organized for first-time DevOps operators.

The structure follows one simple rule:

- data structure first: top-level folders are apply-order groups
- each group contains root modules in apply order
- each root module is self-contained and readable

## Apply-order groups

- `aa-catalog/`
  - shared catalog data, schema contracts, and reusable Terraform modules
- `ab-hub-spoke/`
  - hub-spoke connectivity roots (`aa-foundation`, `ba-hubs`, `bb-sp1-connectivity`, `ca-spokes`)
- `az-hub-projects/`
  - projects connected to the hub
  - current example: `datafactory` with roots in apply order

Private repositories in Azure DevOps (`xyz9ops`):

- `homeapps` (private)
- `projects` (private)
- `offices` (private)

Only connectivity to `sp1` stays here, under `ab-hub-spoke/bb-sp1-connectivity`.

## Quick start

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

- `make -C ab-hub-spoke list`
- `make -C ab-hub-spoke plan`
- `make -C az-hub-projects/datafactory plan`

## Documentation

- Architecture: `docs/ARCHITECTURE.md`
- Repository map: `docs/REPOSITORY_MAP.md`
- Contributing: `CONTRIBUTING.md`
- Security: `SECURITY.md`
