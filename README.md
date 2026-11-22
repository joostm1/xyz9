# xyz9

Public infrastructure-as-code repository for xyz9's hub-spoke project.

xyz9 is an imaginary company's IT department, providing shared identity, networking, landing-zone, application, and data infrastructure. This repository contains the shared catalog, hub-and-spoke connectivity, and connected workload examples for people who need to understand, maintain, or extend that infrastructure:

- platform and network engineers working on hub-spoke connectivity
- project teams that need hub-connected workload examples
- contributors who maintain shared catalog contracts and Terraform modules

## What is here

The structure follows one rule:

- data structure first: top-level folders are apply-order groups
- each group contains root modules in apply order
- each root module is self-contained and readable

## Apply-order groups

- `catalog/`
  - shared catalog data, schema contracts, and reusable Terraform modules
- `azhubs/`
  - hub-spoke connectivity roots (`aa-foundation`, `ba-hubs`, `bb-sp1-connectivity`, `ca-spokes`)
- `spoke-projects/`
  - projects connected to the hub
  - current example: `datafactory` with roots in apply order

The ``azhubs/bb-sp1-connectivity`` root manages connectivity to `sp1`.

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
