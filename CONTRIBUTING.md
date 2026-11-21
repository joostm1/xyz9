# Contributing

Thanks for your interest in improving `xyz9`.

## Principles

- Keep the repository educational and usable in real environments
- Prefer clear, explicit data models over hidden logic
- Keep changes scoped; avoid mixing unrelated migrations and refactors
- Never commit secrets, credentials, keys, or private runtime artifacts

## Where to start

1. Read `README.md` for project purpose and layout
2. Read `aa-catalog/catalog/AGENTS.md` for architecture intent and conventions
3. Inspect the relevant apply-order group (`aa-catalog`, `ab-hub-spoke`, `az-hub-projects`)

## Development workflow

1. Create a branch from `main`
2. Make focused changes with clear commit messages
3. Run local checks that are feasible in your environment
4. Open a PR with context, impact, and follow-up notes

## Typical local commands

```sh
make list
make validate
make plan
```

Per group/project:

```sh
make -C ab-hub-spoke validate
make -C aa-catalog/catalog/terraform validate
make -C az-hub-projects/datafactory validate
```

## Pull request expectations

- Explain the why, not only the what
- Link affected paths and modules
- Mention state/config migration implications when relevant
- Add docs updates when behavior or intent changes

## Security and sensitive data

- Do not include real secrets in examples or tests
- Treat Terraform state as sensitive
- Follow `SECURITY.md` for reporting issues
