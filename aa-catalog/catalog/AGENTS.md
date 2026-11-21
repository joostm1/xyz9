# XYZ9 organization agent instructions

## Organization

XYZ9 is a learning environment for enterprise IT: identity, networking, landing zones, applications, and data platforms, with explicit trade-offs. `org.json` defines organization-wide facts such as the DNS domain, supplier identifiers, and X.509 CA metadata.

This repository (`config`) is the shared organization catalog and Terraform toolkit. In this consolidated `stack` repository, project folders reference it through a local `org/` path. It contains:

- `projects/*.json`: declarative project seeds
- `schemas/projects.schema.json`: the shared project contract
- `terraform/`: orchestration and reusable Terraform modules
- `projects/homeapps/<office>/`: static files associated with office-hosted applications

## Projects and responsibilities

The public stack repository includes four projects:

1. `projects` is the bootstrap control plane for all catalog projects. It creates project owner identities and groups, certificates, `${projectName}-config` secrets, shared-subscription access, backend access grants, and optional Azure DevOps projects. It owns bootstrap identity; `datacenter` does not.
2. `datacenter` is the centrally controlled Azure network and landing-zone project. It creates central configuration, private DNS, regional hub VNets and Linux NVAs, the IPsec/DNS mesh, office-router mesh files, and connected project spokes. For projects with `hub_location`, it contributes spoke connectivity under `projects.datacenter`.
3. `datafactory` is a cloud data-platform project used to learn Azure Data Factory and Snowflake architecture. It provisions the Snowflake landing zone, Entra SSO and SCIM, Azure DevOps repositories and pipelines, shared and per-dataset ADF resources, private connectivity, and dataset-specific Azure and Snowflake resources.
4. `config` provides shared catalog data, schemas, and reusable Terraform modules consumed by the project repositories.

`homeapps` remains a private companion repository in Azure DevOps. Its application catalog and static files stay under `config/projects/homeapps/` so shared configuration remains versioned in this public stack.

Repository-specific `AGENTS.md` files supplement this guidance with local roots and operational details.

## Bootstrap contract

The external `iac` foundation provides:

- Azure subscription `xyz9-iac` (`c15a95c3-5ab1-4e34-a713-2cb3495bff7c`), resource group `iac`, parent management group `mg1`, and shared subscription `xyz9-projects1`.
- Corporate Key Vault `xz9kviac` and storage account `xz9saiac`.
- Vault secrets `xyz9-billing-account`, `cloudflare-dns-editzonekey`, `cloudflare-dns-zoneid`, `nvaAdminUserName`, and `adminPK`. Add workload-specific Snowflake and application secrets before applying those workloads.
- Private Terraform backend containers for `iac` and every catalog project.
- Entra ID and Azure DevOps organization `xyz9ops`.
- An operator or pipeline identity that can use the backend, read the required vault objects, and perform the Azure, Entra, billing, and Azure DevOps operations requested by the selected root.

Pass the foundation coordinates through `~/.tfbackend.hcl` and `~/.tfvars`. Never put credentials or secret values in git.

XYZ9 then applies:

1. `projects` creates project identities, credentials, config secrets, and access grants.
2. `datacenter` builds hub-and-spoke connectivity and office-router IPsec mesh artifacts.
3. Connected workloads such as `datafactory` run after `ab-hub-spoke/ca-spokes`.
4. `homeapps` (private companion repository) applies application workloads on spoke-connected hosts.

Roots that manage office hosts require network access to `egx` and OPI at `sp1`. Terraform imports require the named live resource to exist.

Within a project repository, `resources/Makefile` applies Terraform roots in lexical folder order and destroys them in reverse order. Folder prefixes encode lifecycle order; they do not by themselves prove a remote-state dependency.

Current root sequences are:

- `projects`: `aa-self`, `ba-projects`
- `datacenter`: `aa-config`, `ba-hubs`, `bb-offices`, `ca-spokes`
- `datafactory`: `am-sfbootstrap`, `as-sflz`, `au-devops`, `ba-azure`

Inspect each root's data sources before changing order. For example, `datacenter/bb-offices` and `datacenter/ca-spokes` both depend on `ba-hubs`; they are sibling branches rather than one linear config chain.

## Catalog and living configuration

Each project starts with `projects/${projectName}.json`. Inspect `schemas/projects.schema.json` before editing a seed and validate the result when tooling is available.

Configuration has three representations with different purposes:

- Git seed `projects/${projectName}.json`: desired shape and policy. `roots` and `projects` remain empty in git.
- Key Vault secret `${projectName}-config` in the corporate vault: the project-boundary object enriched by other projects.
- Root `output "config"` in Terraform state: the same-project handoff to successor roots.

The intended contribution namespaces are:

- Project `P` owns only `projects.P` in another project's living config.
- Root `R`, where the repository participates in the config chain, owns only `roots[R]` and emits the complete object.
- Writers preserve all sibling contributions. If two writers need the same path, stop and resolve ownership explicitly.

For example, a living `datafactory` object receives bootstrap identity and subscription data under `projects.projects`, connectivity under `projects.datacenter`, and its own root results under `roots`.

Do not assume every repository uses the complete model. Merge precedence varies by repository; inspect the implementation rather than assuming that `local.config` always has the same construction.

The `projects` repository's current `resources/ba-projects` implementation reconstructs target config secrets from the seed and `projects.projects`; reapplying it after another project has contributed can discard that later contribution. Until that writer preserves the existing object, reapply `ab-hub-spoke/ca-spokes` after `projects` for connected projects and inspect the plan carefully.

Never put runtime IDs, generated credentials, private keys, or contributed config back into project seeds. Never print or persist Key Vault secret values outside their intended store. Treat Terraform state as sensitive because generated certificates, passwords, and tokens may be present there.

## Shared Terraform tooling

Shared modules under `terraform/modules` include recursive merges, keyed-map joins, scope/tree enumeration, SSH file installation, Azure networking and RBAC helpers, and Entra client-credential acquisition. Keep reusable organization-wide behavior here; keep project-specific modules in the project repository.

Within `stack`, shared changes in `config` are consumed immediately by project folders through their local `org` path.

Put resources with similar lifecycles in one Terraform root. When multiple roots are required, use alphabetically ordered lifecycle prefixes such as `resources/af-bootstrap` and `resources/al-nextphase`.

## Rules of the house

- In the spirit of Niklaus Wirth, suggest changes to the providing data structure instead of twisting the consuming algorithm again
- Be brief by default, but explain learning points when they matter.
- When presenting shell commands, minimize line-continuation characters; use them only when they improve readability.
- Do not use blank lines inside or between Terraform blocks such as `resource {}` and `output {}`.
- Prefer Terraform functions over complex `locals` blocks.
- Add short inline comments for non-obvious expressions, such as `# our predecessor`.
- For the `snowflakedb/snowflake` provider, use `snowflake_execute` only when no targeted resource is available.
- When suggesting Snowflake Terraform, explain why the selected role and provider alias are appropriate and briefly identify plausible alternatives.
- Distinguish a data role from a graph relation when naming: `engineer` is a role on a node; `datasets.nyt` is a node in the scope tree.
- For data transformations, include a small concrete input/output example.
- Apps run in WSL or Windows; translate paths such as `C:\Users\USER1\` to `/mnt/c/Users/USER1` and vice versa.
- When a prompt could be clearer, suggest a concise version that can be reused.
- If `make destroy` fails for a transient or partial-teardown reason, retry it. If the same failure pattern persists, stop and explain the blocker.

## Hard constraints

- For Terraform plan and apply, do not persist until done. If `terraform plan`, `terraform apply`, `make plan`, or `make apply` fails, summarize the failure, propose a fix, and stop.
- All Azure storage accounts suggested or implemented must set:
  - `shared_access_key_enabled = false`
  - `allow_nested_items_to_be_public = false`
  - `is_hns_enabled = false` because HNS has failed in this environment
  - `default_to_oauth_authentication = true`
