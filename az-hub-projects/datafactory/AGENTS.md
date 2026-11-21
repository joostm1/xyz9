# datafactory agent instructions

Read [`org/AGENTS.md`](org/AGENTS.md) first for shared rules.

## This repository

- Project catalog: `org/projects/datafactory.json` (`goal.objective`)
- In this consolidated stack, `org` points to `aa-catalog/catalog`; keep catalog and project changes coordinated.
- Local modules: `modules/` (project-specific); org modules stay in `org/terraform/modules`
- Root modules: `ab-sfbootstrap`, `ac-sflz`, `ad-devops`, `ae-azure` (apply in lexical order via `Makefile`)
