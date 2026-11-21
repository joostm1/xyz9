# xyz9 stack

Public infrastructure-as-code repository for the XYZ9 learning environment.

The stack focuses on:

- shared control-plane bootstrapping (`projects`)
- hub-and-spoke connectivity (`datacenter`)
- a cloud data-platform workload (`datafactory`)
- shared org catalog, schemas, and Terraform tooling (`config`)

## Repository layout

- `config/`: shared organization catalog (`org.json`, `projects/*.json`), schemas, and shared Terraform modules
- `projects/`: bootstrap identities, access, certificates, and per-project config-secret handoffs
- `datacenter/`: hub VNets, NVAs, office IPsec mesh artifacts, and spoke connectivity contributions
- `datafactory/`: Azure Data Factory + Snowflake learning workload

## Private companion repository

`homeapps` intentionally stays outside this repository in a private Azure DevOps repository.

## Orchestration

- `make list`: list orchestrated top-level projects
- `make validate`: run validate for each project that has `resources/`
- `make plan` / `make apply`: run in apply order
- `make destroy`: run in reverse order

The top-level `Makefile` delegates to each `*/resources/Makefile`.

## Notes for contributors

- `project_name` convention remains the folder name (for example `projects`, `datacenter`)
- Terraform state keys remain `<root>.tfstate`
- Shared intent and architecture live in `config/AGENTS.md`
