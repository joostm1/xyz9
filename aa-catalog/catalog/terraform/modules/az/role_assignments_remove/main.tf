# Remove all role assignments from resource scope

resource "terraform_data" "remove_role_assignments" {
  provisioner "local-exec" {
    command     = "scripts/removeScopeRoleAssignments.ps1"
    working_dir = path.module
    interpreter = ["pwsh", "-File"]
    environment = {
      resource_scope = base64encode(var.scope)
      check_before   = base64encode(jsonencode(var.check_before))
    }
  }
}

variable "scope" {
  type        = string
  description = "The resource scope from which to remove role assignments."
}
