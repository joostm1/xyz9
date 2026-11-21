# xyz9 hub-spoke stack

Public infrastructure-as-code repository for the xyz9 hub-spoke platform.

This repository is for people who need to understand, maintain, or extend the shared platform layout:

- platform and network engineers working on hub-spoke connectivity
- project teams that need hub-connected workload examples
- contributors who maintain shared catalog contracts and Terraform modules

## What is here

The structure follows one rule:

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

- `make -C ab-hub-spoke list`
- `make -C ab-hub-spoke plan`
- `make -C az-hub-projects/datafactory plan`

## Documentation

- Architecture: `docs/ARCHITECTURE.md`
- Repository map: `docs/REPOSITORY_MAP.md`
- Contributing: `CONTRIBUTING.md`
- Security: `SECURITY.md`
