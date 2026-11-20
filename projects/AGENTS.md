# Agent instructions

This repository creates identities, credentials, configuration handoffs, subscriptions, and access grants that bootstrap other XYZ9 projects. The `iac` repository owns the corporate resource group, vault, storage account, and backend containers.

## Corporate Guidelines

Read and follow `org/AGENTS.md` before changing this repository. It contains the organization-wide project model, Terraform workflow expectations, security rules, and style guidance.

## Repository summary

- `org/` is the `config` corporate configuration submodule, checked out from `../config` on `develop`.
- `org/org.json` defines the XYZ9 organization catalog, supplier names, DNS domain, certificate authority metadata, and locations.
- `org/projects/*.json` are project seed files validated by `org/schemas/projects.schema.json`.
- `resources/` contains Terraform root modules for this project. Root module folders are ordered by lifecycle using the `aa-`, `ba-` prefix convention.
- The project name is the repository directory (`projects`); `org/terraform/Makefile` derives it as two levels above the Terraform root, which selects the seed JSON at `org/projects/projects.json`.
- `resources/aa-self` bootstraps the `projects` identity, project CA, owner certificate, owner service principal, Azure DevOps entitlement, owner group, and project management group access.
- `resources/ba-projects` reads the predecessor root module output and dispatches project resources for every project seed except `projects` itself.
- `resources/ba-projects/project_resources` contains the per-project implementation used by `ba-projects`.

## Local Notes

- Keep Terraform roots in alphabetical lifecycle order under `resources/` so predecessor discovery in `ba-projects` remains valid.
- Same-project root modules should continue the `output "config"` merge chain under `roots[var.state_key]`.
- Treat backend containers as `iac` data. This repository grants project owner groups access but never creates, updates, or deletes the containers.
- Do not print or persist Key Vault secret values, certificate private keys, or generated PKCS12 content.
