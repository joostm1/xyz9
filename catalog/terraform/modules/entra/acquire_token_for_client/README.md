# acquire_token_for_client

Acquires an Entra OAuth2 access token for a confidential client by using either a client secret or a base64-encoded PKCS#12/P12 certificate bundle.

## Example: Azure Resource Manager With P12

```hcl
module "arm_token" {
  source = "../../org/terraform/modules/entra/acquire_token_for_client"

  tenant_id  = var.tenant_id
  client_id  = local.config.projects.identity.owner.app_client_id
  p12_bundle = data.azurerm_key_vault_secret.owner_p12.value
  scopes     = ["https://management.azure.com/.default"]
}
```

## Example: Client Secret

```hcl
module "arm_token" {
  source = "../../org/terraform/modules/entra/acquire_token_for_client"

  tenant_id          = var.tenant_id
  client_id          = var.client_id
  client_credential  = var.client_secret
  scopes             = ["https://management.azure.com/.default"]
}
```

The module uses Terraform's `external` provider and runs the helper with `uv run --script`. The runner only needs `uv`; Python dependencies are declared inline in `scripts/acquire_token.py`.
