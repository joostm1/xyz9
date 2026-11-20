# stack

This repository consolidates the Terraform project repositories in apply order:

1. `config`
2. `offices`
3. `projects`
4. `homeapps`
5. `datacenter`
6. `datafactory`

The goal is to keep existing backend state coordinates stable while consolidating source control.

## Layout

Each project is preserved as a top-level folder so existing conventions continue to work:

- `project_name` remains the folder name (for example `offices`, `projects`, `homeapps`)
- Root module folder names under `resources/` stay unchanged (for example `aa-config`, `ba-hubs`)
- Remote state keys stay `<root>.tfstate`

## State migration

No Terraform state object move is expected when these invariants are preserved:

- State container remains per project (for example `offices`, `projects`, `homeapps`, `datacenter`, `datafactory`)
- State key remains per root folder (for example `aa-config.tfstate`)

If either the project folder name or root folder names change later, plan a dedicated state move.

## Orchestration

- Run all project resources in apply order: `make plan` or `make apply`
- Run all project resources in reverse order for teardown: `make destroy`

The top-level `Makefile` delegates to each `*/resources/Makefile`.

## Immediate follow-up

1. Run `make validate` at repo root.
2. Run project-level `make plan` and compare against current expected plans.
3. Update CI pipeline paths to this consolidated repository.
4. Archive source repos after successful cutover.
