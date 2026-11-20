variable "left" {
  type        = any
  description = "Left map of objects to join."
}
variable "right" {
  type        = any
  description = "Right map of objects to join."
}
variable "join_type" {
  type        = string
  description = "Join type. Supported values are left and inner."
  default     = "inner"
  validation {
    condition     = contains(["left", "inner"], var.join_type)
    error_message = "join_type must be left or inner."
  }
}
variable "left_match_attr" {
  type        = string
  description = "Dot-separated attribute path on each left object used for matching."
  default     = "key"
}
variable "right_match_attr" {
  type        = string
  description = "Dot-separated attribute path on each right object used for matching."
}
variable "key_attrs" {
  type        = list(string)
  description = "Output attribute names used, in order, to build each result key."
}
data "external" "this" {
  program = ["jq", "-c", "-f", "${path.module}/map_join.jq"]
  query = {
    join_type        = var.join_type
    key_attrs        = jsonencode(var.key_attrs)
    left             = jsonencode(var.left)
    left_match_attr  = var.left_match_attr
    right            = jsonencode(var.right)
    right_match_attr = var.right_match_attr
  }
}
locals {
  entries = jsondecode(data.external.this.result.entries)
  by_key  = jsondecode(data.external.this.result.by_key)
}
output "entries" {
  value       = local.entries
  description = "Joined entries as a list."
}
output "by_key" {
  value       = local.by_key
  description = "Joined entries keyed by generated key."
}
terraform {
  required_providers {
    external = {
      source = "hashicorp/external"
    }
  }
}
