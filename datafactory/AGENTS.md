# datafactory agent instructions

Read [`org/AGENTS.md`](org/AGENTS.md) first for shared rules.

## This repository

- Project catalog: `org/projects/datafactory.json` (`goal.objective`)
- `org` points to the local `../config` folder in this consolidated repository; keep config and project changes coordinated.
- Local modules: `modules/` (project-specific); org modules stay in `org/terraform/modules`
- Root modules: `resources/am-sfbootstrap`, `resources/as-sflz`, `resources/au-devops`, `resources/ba-azure` (apply in lexical order via `resources/Makefile`)
