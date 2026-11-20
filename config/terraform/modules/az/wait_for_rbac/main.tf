variable "scope" {
  type        = string
  description = "Resource id of the scope the role assignment must be listed on."
}
variable "role_definition_name" {
  type        = string
  description = "Azure role definition name, for example Storage Blob Data Contributor."
}
variable "object_id" {
  type        = string
  description = "Entra object id of the principal that must hold the role."
}
variable "assignment_id" {
  type        = string
  description = "Role assignment resource id. Changing it runs the poll again."
}
variable "timeout_seconds" {
  type        = number
  default     = 300
  description = "Seconds to poll before failing."
}
variable "interval_seconds" {
  type        = number
  default     = 10
  description = "Seconds between polls."
}
# assignment_id is not sent to the script; a new id replaces this object and polls again
resource "terraform_data" "this" {
  input = {
    scope         = var.scope
    role          = var.role_definition_name
    object_id     = var.object_id
    assignment_id = var.assignment_id
  }
  provisioner "local-exec" {
    command     = "scripts/wait_for_rbac.py"
    working_dir = path.module
    interpreter = ["python3"]
    environment = {
      scope                = var.scope
      role_definition_name = var.role_definition_name
      object_id            = var.object_id
      timeout_seconds      = tostring(var.timeout_seconds)
      interval_seconds     = tostring(var.interval_seconds)
    }
  }
}
output "id" {
  description = "Id of the poll. Depend on this module so callers run after the assignment is listed."
  value       = terraform_data.this.id
}
