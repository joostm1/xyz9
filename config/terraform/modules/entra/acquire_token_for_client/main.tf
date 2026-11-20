variable "tenant_id" {
  description = "The Entra tenant ID where the client application is registered."
  type        = string
}

variable "client_id" {
  description = "The client/application ID to authenticate as."
  type        = string
}

variable "scopes" {
  description = "OAuth2 scopes to request. For Azure Resource Manager use [\"https://management.azure.com/.default\"]."
  type        = list(string)
}

variable "client_credential" {
  description = "Client secret for OAuth2 client credentials authentication. Set exactly one of client_credential or p12_bundle."
  type        = string
  default     = null
  sensitive   = true

  validation {
    condition     = var.client_credential == null || length(var.client_credential) > 0
    error_message = "client_credential must be null or a non-empty string."
  }
}

variable "p12_bundle" {
  description = "Base64-encoded PKCS#12/P12 bundle containing the client certificate and private key. Set exactly one of client_credential or p12_bundle."
  type        = string
  default     = null
  sensitive   = true

  validation {
    condition     = var.p12_bundle == null || length(var.p12_bundle) > 0
    error_message = "p12_bundle must be null or a non-empty string."
  }
}

variable "p12_password" {
  description = "Password for p12_bundle. Leave null for an unprotected bundle."
  type        = string
  default     = null
  sensitive   = true
}

variable "token_endpoint" {
  description = "Optional token endpoint override. Defaults to the v2.0 endpoint for tenant_id."
  type        = string
  default     = null
}

locals {
  has_client_credential = var.client_credential != null
  has_p12_bundle        = var.p12_bundle != null
  token_endpoint        = coalesce(var.token_endpoint, "https://login.microsoftonline.com/${var.tenant_id}/oauth2/v2.0/token")
}

resource "terraform_data" "credential_validation" {
  input = {
    has_client_credential = local.has_client_credential
    has_p12_bundle        = local.has_p12_bundle
  }

  lifecycle {
    precondition {
      condition     = local.has_client_credential != local.has_p12_bundle
      error_message = "Set exactly one of client_credential or p12_bundle."
    }
  }
}

data "external" "token" {
  program = ["uv", "run", "--script", "${path.module}/scripts/acquire_token.py"]

  query = {
    token_endpoint    = local.token_endpoint
    client_id         = var.client_id
    scopes            = join(" ", var.scopes)
    client_credential = var.client_credential == null ? "" : var.client_credential
    p12_bundle        = var.p12_bundle == null ? "" : var.p12_bundle
    p12_password      = var.p12_password == null ? "" : var.p12_password
  }

  depends_on = [terraform_data.credential_validation]
}

terraform {
  required_providers {
    external = {
      source = "hashicorp/external"
    }
  }
}

output "access_token" {
  description = "The acquired OAuth2 access token."
  value       = sensitive(data.external.token.result.access_token)
  sensitive   = true
}

output "expires_on" {
  description = "Unix timestamp at which the access token expires."
  value       = tonumber(data.external.token.result.expires_on)
}

output "token_type" {
  description = "The OAuth2 token type returned by Entra."
  value       = data.external.token.result.token_type
}
