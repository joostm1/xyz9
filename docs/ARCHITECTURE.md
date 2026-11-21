# Architecture

## Overview

`xyz9` models a small enterprise-style platform with clear ownership boundaries:

- `projects` bootstraps project identities, access, and config-seed handoffs
- `datacenter` provides shared network/connectivity foundations
- `datafactory` is a workload project consuming shared platform capabilities
- `config` provides the shared catalog, schema contracts, and reusable modules

## Configuration model

Each project starts from a seed JSON under `config/projects/*.json`.

Configuration then flows through:

1. seed JSON in git
2. project config secret in Key Vault (`${projectName}-config`)
3. Terraform root `output "config"` handoffs

Contributions are namespaced under:

- `roots[<state_key>]` for same-project root contributions
- `projects[<contributing_project>]` for cross-project contributions

## Execution order

Current high-level apply flow:

1. `projects`
2. `datacenter`
3. workload projects (for example `datafactory`)
4. private companion projects (for example `homeapps` in private Azure DevOps)

Within a project, roots run in lexical order via `resources/Makefile`.

## Networking direction

The public stack prioritizes hub-and-spoke connectivity:

- hubs and shared network services in `datacenter`
- office router mesh artifacts in `datacenter/resources/bb-offices`
- workload spokes and connectivity contributions in `datacenter/resources/ca-spokes`

## Non-goals

- This repo does not host private application runtime repositories
- This repo does not include production secrets or runtime credentials
