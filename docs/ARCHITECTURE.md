# Architecture

## Design principle

The repository is structured around configuration exchange and apply order:

- top-level folders are apply-order groups
- each group contains root modules in explicit lifecycle order
- configuration lives in data first (`catalog`), then flows into roots

This keeps control flow simple and predictable.

## Public structure

- `catalog`
  - shared project seeds, schemas, and reusable Terraform modules
- `azhubs`
  - `aa-foundation`
  - `ba-hubs`
  - `bb-sp1-connectivity`
  - `ca-spokes`
- `spoke-projects/datafactory`
  - `ab-sfbootstrap`
  - `ac-sflz`
  - `ad-devops`
  - `ae-azure`

## Configuration exchange model

Project seeds are read from `catalog/projects/*.json`.

Runtime configuration exchange uses:

1. seed JSON in git
2. project config secret in Key Vault (`${projectName}-config`)
3. root `output "config"` handoff objects

Contribution ownership remains namespaced:

- `roots[<state_key>]` for same-project root contributions
- `projects[<contributing_project>]` for cross-project contributions

## Execution model

- root `Makefile` runs group folders in apply order
- each group `Makefile` runs its own roots in apply order
- destroy runs in reverse order

## Private boundaries

The following repositories are private in Azure DevOps (`xyz9ops`):

- `homeapps`
- `projects`
- `offices`

Only connectivity to `sp1` remains in the public hub-spoke group.
