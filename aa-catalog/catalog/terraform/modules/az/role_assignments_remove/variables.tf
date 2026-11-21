variable "scope" {
  description = "The resource scopes of which to remove the role assignments"
  type        = string
}

variable "check_before" {
  description = "Assignments to be checked to exist before removal"
  type = set(object({
    principalId        = string
    roleDefinitionName = string
    principalType      = string
    scope              = string
  }))
}

