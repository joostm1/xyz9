---
name: terraform-import
description: Parse Terraform apply or plan errors that say resources already exist and generate exact import commands. Use this whenever the user pastes "already exists - to be managed via Terraform this resource needs to be imported" errors or asks for `make import to=... id=...` commands, especially for module addresses with index keys.
---

# Terraform Import Helper

Turn Terraform "already exists" errors into ready-to-run import commands.

## What to extract

For each error block, read:

1. The resource ID from the line containing `Error: a resource with the ID "..." already exists`
2. The Terraform address from the line starting with `with ...`

Create one `(to, id)` pair per block.

## Output format

Return commands in this exact form:

```bash
make import to='<terraform-address>' id='<resource-id>'
```

Rules:

- Keep one command per line.
- Preserve the original order from the error output.
- Skip duplicates.
- Do not modify resource IDs.
- Do not normalize or rewrite Terraform addresses.
- Describe only current behavior; do not include historical context unless the user explicitly asks for it.

## Validation checklist

Before returning results, verify:

- Number of generated commands equals number of unique error blocks with both ID and `with` address.
- Every command has both `to=` and `id=`.
- Every `to=` value matches exactly what appeared after `with` (without trailing comma).
- Every `id=` value matches exactly what appeared in the error line.
- Verify index quotes remain literal as `"..."`.

## Example

Input block:

```text
Error: a resource with the ID "/subscriptions/.../virtualNetworkLinks/datafactory-privatelink.blob.core.windows.net" already exists
with module.spoke["apc1-datafactory"].azurerm_private_dns_zone_virtual_network_link.spoke_vnet_dns_link["privatelink.blob.core.windows.net"],
```

Output:

```bash
make import to='module.spoke["apc1-datafactory"].azurerm_private_dns_zone_virtual_network_link.spoke_vnet_dns_link["privatelink.blob.core.windows.net"]' id='/subscriptions/.../virtualNetworkLinks/datafactory-privatelink.blob.core.windows.net'
```
