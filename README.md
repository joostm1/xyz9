# xyz9 stack

Public infrastructure-as-code repository for the XYZ9 learning environment.

## Purpose

This repository is a practical reference for operating a small but realistic platform:

- identity and access bootstrapping
- hub-and-spoke network topology
- workload onboarding on shared connectivity
- cross-project configuration handoffs

It is intended to be useful both as working infrastructure code and as a learning artifact.

## What is in scope

- `config/`: shared org catalog (`org.json`, `projects/*.json`), schemas, and reusable Terraform modules
- `projects/`: bootstrap control plane (project identities, certs, access grants, config-secret seeds)
- `datacenter/`: hubs, VPN mesh artifacts, and spoke connectivity contributions
- `datafactory/`: workload example that consumes shared platform capabilities

`homeapps` intentionally stays outside this repository in a private Azure DevOps repository.

## Repository guide

- Architecture and flow: `docs/ARCHITECTURE.md`
- Contributor workflow: `CONTRIBUTING.md`
- Security policy: `SECURITY.md`
- Current priorities: `docs/ROADMAP.md`
- Repository file map: `docs/REPOSITORY_MAP.md`

## Quick start

Prerequisites:

- Terraform CLI
- Azure CLI auth for the target tenant/subscription
- Access to the bootstrap backend and key vault coordinates

Common commands:

- `make list` - list orchestrated top-level projects
- `make validate` - validate all project roots
- `make plan` - plan in apply order
- `make apply` - apply in apply order
- `make destroy` - destroy in reverse order

The top-level `Makefile` delegates to each `*/resources/Makefile`.

## Design conventions

- Project folder name is the Terraform `project_name`
- State key per root is `<root>.tfstate`
- Shared intent and architecture source lives in `config/AGENTS.md`
