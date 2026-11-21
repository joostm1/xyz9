# XYZ9 agent instructions

This file defines shared operating rules for agents across the whole `xyz9` repository.
Repository-specific `AGENTS.md` files add local context and constraints.

## Rules of the house

- In the spirit of Niklaus Wirth, suggest changes to the providing data structure instead of twisting the consuming algorithm.
- Be brief by default, but explain learning points when they matter.
- When presenting shell commands, minimize line-continuation characters; use them only for very long lines.
- Do not use blank lines inside or between Terraform blocks such as `resource {}` and `output {}`.
- Prefer Terraform functions over complex `locals` blocks.
- When a prompt could be clearer, suggest a concise version that can be reused.

## Organization and infrastructure

XYZ9 is a learning environment for enterprise IT: identity, networking, landing zones, applications, and data platforms, with explicit trade-offs. `catalog/org.json` defines organization-wide facts such as the DNS domain, supplier identifiers, and X.509 CA metadata.

`catalog/` is the shared organization catalog and Terraform toolkit. It contains project seeds under `projects/`, schemas under `schemas/`, and orchestration and reusable modules under `terraform/`. Project folders use a local `org/` path to consume the catalog.

The public repository contains the shared catalog, hub-and-spoke infrastructure under `azhubs/`, and connected workloads under `spoke-projects/`. Private companion repositories in Azure DevOps (`xyz9ops`) include `homeapps`, `projects`, and `offices`. `homeapps` application catalog data and static files remain under `catalog/projects/homeapps/`.

The external `iac` foundation provides:

- Azure subscription `xyz9-iac` (`c15a95c3-5ab1-4e34-a713-2cb3495bff7c`), resource group `iac`, parent management group `mg1`, and shared subscription `xyz9-projects1`.
- Corporate Key Vault `xz9kviac` and storage account `xz9saiac`.
- Vault secrets `xyz9-billing-account`, `cloudflare-dns-editzonekey`, `cloudflare-dns-zoneid`, `nvaAdminUserName`, and `adminPK`. Add workload-specific Snowflake and application secrets before applying those workloads.
- Private Terraform backend containers for `iac` and every catalog project.
- Entra ID and Azure DevOps organization `xyz9ops`.
- An operator or pipeline identity that can use the backend, read the required vault objects, and perform the Azure, Entra, billing, and Azure DevOps operations requested by the selected root.

Pass the foundation coordinates through `~/.tfbackend.hcl` and `~/.tfvars`. Never put credentials or secret values in git.

The intended high-level order is: create project identities and access grants, build central hub-and-spoke connectivity, then apply connected workloads. Workloads with `hub_location` depend on `azhubs/ca-spokes`; private companion repositories may apply additional workloads to spoke-connected hosts. Roots that manage office hosts require network access to `egx` and OPI at `sp1`. Terraform imports require the named live resource to exist.

## Terraform roots and configuration

Use each project's `Makefile` as the authoritative root apply order; destroys run in reverse order. Folder prefixes encode lifecycle order but do not by themselves prove a remote-state dependency. Inspect each root's data sources before changing its order.

Each project starts with `projects/${projectName}.json`. Inspect `schemas/projects.schema.json` before editing a seed and validate the result when tooling is available. Configuration has three representations:

- Git seed `projects/${projectName}.json`: desired shape and policy. `roots` and `projects` remain empty in git.
- Key Vault secret `${projectName}-config`: the project-boundary object enriched by other projects.
- Root `output "config"` in Terraform state: the same-project handoff to successor roots.

The intended contribution namespaces are:

- Project `P` owns only `projects.P` in another project's living config.
- Root `R`, where the repository participates in the config chain, owns only `roots[R]` and emits the complete object.
- Writers preserve all sibling contributions. If two writers need the same path, stop and resolve ownership explicitly.

For example, a living `datafactory` object receives bootstrap identity and subscription data under `projects.projects`, connectivity under `projects.datacenter`, and its own root results under `roots`.

Do not assume every repository uses the complete model. Merge precedence varies; inspect the implementation rather than assuming that `local.config` is constructed the same way everywhere. Never put runtime IDs, generated credentials, private keys, or contributed config back into project seeds. Never print or persist Key Vault secret values outside their intended store. Treat Terraform state as sensitive because generated certificates, passwords, and tokens may be present there.

Shared modules under `catalog/terraform/modules` include recursive merges, keyed-map joins, scope/tree enumeration, SSH file installation, Azure networking and RBAC helpers, and Entra client-credential acquisition. Keep reusable organization-wide behavior in the catalog and project-specific modules in their project repositories. Shared catalog changes are consumed by project folders through their local `org` path.

Put resources with similar lifecycles in one Terraform root. For Terraform plan and apply, do not persist until done. If `terraform plan`, `terraform apply`, `make plan`, or `make apply` fails, summarize the failure, propose a fix, and stop.

All Azure storage accounts suggested or implemented must set:

- `shared_access_key_enabled = false`
- `allow_nested_items_to_be_public = false`
- `is_hns_enabled = false` because HNS has failed in this environment
- `default_to_oauth_authentication = true`
