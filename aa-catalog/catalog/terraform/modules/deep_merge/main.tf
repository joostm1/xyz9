variable "base" {
  type        = any
  description = "Base value to merge into."
  default     = {}
}

variable "override" {
  type        = any
  description = "Override value to merge on top of base."
  default     = {}
}

data "external" "this" {
  program = ["jq", "-c", "-f", "${path.module}/deep_merge.jq"]
  query = {
    base     = jsonencode(var.base)
    override = jsonencode(var.override)
  }
}

locals {
  result = jsondecode(data.external.this.result.result)
}

output "result" {
  value       = local.result
  description = "Recursive merge of base and override. Objects merge recursively; non-object override values replace base values."
}

terraform {
  required_providers {
    external = {
      source = "hashicorp/external"
    }
  }
}
