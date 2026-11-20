# XYZ9 organization agent instructions

## Organization

XYZ9 is a learning environment for enterprise IT: identity, networking, landing zones, applications, and data platforms, with explicit trade-offs. `org.json` defines organization-wide facts such as the DNS domain, supplier identifiers, and X.509 CA metadata.

This repository (`config`) is the shared organization catalog and Terraform toolkit. Project repositories include it as the `org/` submodule. It contains:

- `projects/*.json`: declarative project seeds
- `schemas/projects.schema.json`: the shared project contract
- `terraform/`: orchestration and reusable Terraform modules
- `projects/offices/<office>/`: static files associated with an office

## Projects and responsibilities

The catalog currently describes five projects:

1. `offices` owns physical-office network data and shared location services. For Stratusplein 1 (`sp1`) it catalogs the EdgeRouter-facing LAN, WAN, DHCP, DNS, forwarding, and address-space configuration. Its Terraform creates the organization CA, derives Cloudflare records from live office hosts, owns the Let's Encrypt account, issues the `egx` certificate, and owns its Azure Pipelines definition. It does not deploy the base EdgeRouter configuration.
2. `homeapps` owns applications hosted on the OPI system at `sp1`: application certificates, TLS installation, static host configuration, Key Vault-backed host secrets, generated Docker Compose projects, and selected off-site application-data backups. Its current services include Home Assistant, Docker Mailserver, nginx, PostgreSQL, UniFi, and Vaultwarden.
3. `projects` is the bootstrap control plane for all catalog projects. It creates project owner identities and groups, certificates, `${projectName}-config` secrets, shared-subscription access, backend access grants, and optional Azure DevOps projects. It owns bootstrap identity; `datacenter` does not.
4. `datacenter` is the centrally controlled Azure network and landing-zone project. It creates central configuration, private DNS, regional hub VNets and Linux NVAs, the IPsec/DNS mesh, office-router mesh files, and connected project spokes. For projects with `hub_location`, it contributes spoke connectivity under `projects.datacenter`.
5. `datafactory` is a cloud data-platform project used to learn Azure Data Factory and Snowflake architecture. It provisions the Snowflake landing zone, Entra SSO and SCIM, Azure DevOps repositories and pipelines, shared and per-dataset ADF resources, private connectivity, and dataset-specific Azure and Snowflake resources.

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

1. `offices/resources/aa-ca` creates `xyz9-ca` in `xz9kviac`.
2. `projects` creates project identities, credentials, config secrets, and access grants.
3. `offices/resources/aa-config` and `datacenter` create shared location and cloud connectivity.
4. `homeapps` runs after `offices/resources/aa-config`; it consumes the offices ACME state.
5. Connected workloads such as `datafactory` run after `datacenter/resources/ca-spokes`.

Roots that manage office hosts also require network access to `egx` and OPI at `sp1`. Terraform imports require the named live resource to exist.

Within a project repository, `resources/Makefile` applies Terraform roots in lexical folder order and destroys them in reverse order. Folder prefixes encode lifecycle order; they do not by themselves prove a remote-state dependency.

Current root sequences are:

- `offices`: `aa-ca`, `aa-config`
- `homeapps`: `aa-acme`, `aa-apps`, `ba-docker-data`
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

Do not assume every repository uses the complete model. `offices` and `homeapps` currently consume bootstrap config but do not emit a full `output "config"` chain. Merge precedence also varies by repository; inspect the implementation rather than assuming that `local.config` always has the same construction.

The `projects` repository's current `resources/ba-projects` implementation reconstructs target config secrets from the seed and `projects.projects`; reapplying it after another project has contributed can discard that later contribution. Until that writer preserves the existing object, reapply `datacenter/resources/ca-spokes` after `projects` for connected projects and inspect the plan carefully.

Never put runtime IDs, generated credentials, private keys, or contributed config back into project seeds. Never print or persist Key Vault secret values outside their intended store. Treat Terraform state as sensitive because generated certificates, passwords, and tokens may be present there.

## Shared Terraform tooling

Shared modules under `terraform/modules` include recursive merges, keyed-map joins, scope/tree enumeration, SSH file installation, Azure networking and RBAC helpers, and Entra client-credential acquisition. Keep reusable organization-wide behavior here; keep project-specific modules in the project repository.

Use this repository as the `org/` submodule and respect the revision pinned by the consuming repository. Commit shared changes in `org` before updating and committing the parent repository's submodule reference.

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
