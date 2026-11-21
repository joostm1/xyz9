variable "tree" {
  type        = any
  description = "Nested scope object to walk. Every object containing enum_key as a list produces enumerated entries."
  default     = {}
}

variable "enum_key" {
  type        = string
  description = "Object key containing the enumerable values. For project scopes this is typically roles."
}
variable "enum_value_name" {
  type        = string
  description = "Name of the output attribute that stores each expanded value from enum_key."
}

variable "segment_translations" {
  type        = map(string)
  description = "Optional path segment translations used when generating keys. Unmapped segments keep their original value."
  default     = {}
}

data "external" "this" {
  program = ["jq", "-c", "-f", "${path.module}/scope_enumerator.jq"]
  query = {
    enum_key             = var.enum_key
    enum_value_name      = var.enum_value_name
    segment_translations = jsonencode(var.segment_translations)
    tree                 = jsonencode(var.tree)
  }
}

locals {
  entries = jsondecode(data.external.this.result.entries)
  by_key  = jsondecode(data.external.this.result.by_key)
}

output "entries" {
  value       = local.entries
  description = "Enumerated scope entries as a list. Each entry has key, path, normalized_path, path_key, path_label, enum_key, the configured enum_value_name field, and name."
}

output "by_key" {
  value       = local.by_key
  description = "Enumerated scope entries keyed by generated key."
}

terraform {
  required_providers {
    external = {
      source = "hashicorp/external"
    }
  }
}
