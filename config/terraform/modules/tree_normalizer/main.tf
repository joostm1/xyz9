variable "tree" {
  type        = any
  description = "Nested object to walk. Every configured collection key is normalized into Terraform-friendly entries."
  default     = {}
}

variable "collection_keys" {
  type        = list(string)
  description = "Object keys whose child objects should be emitted as normalized entries."
}

variable "singular_segments" {
  type        = map(string)
  description = "Optional segment translations used when reporting normalized paths, for example schemas = schema."
  default     = {}
}

data "external" "this" {
  program = ["jq", "-c", "-f", "${path.module}/tree_normalizer.jq"]
  query = {
    collection_keys   = jsonencode(var.collection_keys)
    singular_segments = jsonencode(var.singular_segments)
    tree              = jsonencode(var.tree)
  }
}

locals {
  entries       = jsondecode(data.external.this.result.entries)
  by_key        = jsondecode(data.external.this.result.by_key)
  by_collection = jsondecode(data.external.this.result.by_collection)
}

output "entries" {
  value       = local.entries
  description = "Normalized entries as a list. Each entry has key, local_key, collection_key, path, parents, ancestors, and value."
}

output "by_key" {
  value       = local.by_key
  description = "Normalized entries keyed by generated key. Prefer by_collection for resource for_each when different collections may share keys."
}

output "by_collection" {
  value       = local.by_collection
  description = "Normalized entries grouped by collection key, then keyed by generated key."
}

terraform {
  required_providers {
    external = {
      source = "hashicorp/external"
    }
  }
}
