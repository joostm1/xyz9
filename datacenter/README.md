# datacenter

The `datacenter` project provides shared network connectivity for XYZ9 workloads.

## Scope

- Build and maintain Azure hub infrastructure (`ba-hubs`)
- Generate and install office router IPsec mesh files (`bb-offices`)
- Attach workload spokes to hubs (`ca-spokes`)
- Maintain shared DNS/network foundations (`aa-config`)

## Module lifecycle

Terraform roots run in lexical order via `resources/Makefile`:

1. `aa-config`
2. `ba-hubs`
3. `bb-offices`
4. `ca-spokes`

## Data sources

- Primary seed: `org/projects/datacenter.json`
- Shared org facts: `org/org.json`
- Schema: `org/schemas/projects.schema.json`

For detailed contributor and agent guidance, use `datacenter/AGENTS.md` and `config/AGENTS.md`.
