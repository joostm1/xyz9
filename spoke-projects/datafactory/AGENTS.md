# datafactory agent instructions



## This repository

- Project catalog: `org/projects/datafactory.json` (`goal.objective`)
- `org` points to `catalog`; keep catalog and project changes coordinated.
- Local modules: `modules/` (project-specific); org modules stay in `org/terraform/modules`
- Root modules: `ab-sfbootstrap`, `ac-sflz`, `ad-devops`, `ae-azure` (apply in lexical order via `Makefile`)
