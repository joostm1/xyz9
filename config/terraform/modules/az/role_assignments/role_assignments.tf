
variable "assignment_scope" {
  description = "The scope (resource id) for the assignment"
  type        = string
}

variable "entra_groups" {
  type = map(object({
    display_name = string
    object_id    = string
  }))
  description = <<-EOT
    Map of Entra groups keyed by generated scope-role key. Example:
      ```{
        project-admin = {
          display_name = "Project administrators"
          object_id    = "12345678-1234-1234-1234-123456789012"
        }
        regions-apc-manager = {
          display_name = "APC managers"
          object_id    = "23456789-2345-2345-2345-234567890123"
        }
      }```
  EOT
  validation {
    condition = alltrue([
      for group_key, group in var.entra_groups : can(group.display_name) && can(group.object_id)
    ])
    error_message = "Each group must have a display_name and object_id defined."
  }
}

variable "role_assignments" {
  type        = any
  description = <<-EOT
    Nested map of role assignments to be created. A role leaf is a map of Azure role definition names to booleans. Example:
      ```{
          project = {
            admin = {
              "Owner" = true
            }
            regions = {
              apc = {
                manager = {
                  "Reader" = true
                }
              }
            }
          }
        }```
  EOT
  default     = {}
}

data "external" "role_assignments" {
  program = ["jq", "-c", "-f", "${path.module}/role_assignments.jq"]

  query = {
    entra_groups     = jsonencode({ for k, _ in var.entra_groups : k => true })
    role_assignments = jsonencode(var.role_assignments)
  }
}

locals {
  role_assignments = jsondecode(data.external.role_assignments.result.role_assignments)
}

resource "azurerm_role_assignment" "this" {
  for_each             = tomap({ for assignment in local.role_assignments : assignment.name => assignment })
  scope                = var.assignment_scope
  role_definition_name = each.value.roledefinition_name
  principal_id         = var.entra_groups[each.value.group_key].object_id
}

terraform {
  required_providers {
    azurerm = {
      source = "hashicorp/azurerm"
    }
    external = {
      source = "hashicorp/external"
    }
  }
}

# So you can refer to this in other resouces that depend on role assignments
output "assignment_scope" {
  value = var.assignment_scope
}
