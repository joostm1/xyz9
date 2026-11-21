# Repository Map

## Top-level

- `README.md`: project purpose and quick start
- `CONTRIBUTING.md`: contribution workflow and expectations
- `SECURITY.md`: security reporting and secret-handling guidance
- `Makefile`: apply-order group orchestration

## Apply-order groups

- `aa-catalog/catalog`: organization catalog, schema contracts, shared Terraform modules
- `ab-hub-spoke`: hub-spoke roots (`aa-foundation`, `ba-hubs`, `bb-sp1-connectivity`, `ca-spokes`)
- `az-hub-projects/datafactory`: hub-connected workload roots (`ab-sfbootstrap`, `ac-sflz`, `ad-devops`, `ae-azure`)

## Private companion repositories

- `projects` (private, Azure DevOps `xyz9ops`)
- `homeapps` (private, Azure DevOps `xyz9ops`)
- `offices` (private, Azure DevOps `xyz9ops`)

## Documentation

- `docs/ARCHITECTURE.md`: system design and configuration flow
- `docs/ROADMAP.md`: current priorities and direction
- `docs/REPOSITORY_MAP.md`: this guide

## GitHub community health

- `.github/CODEOWNERS`: review ownership
- `.github/pull_request_template.md`: standard PR context
- `.github/ISSUE_TEMPLATE/*`: issue intake templates
