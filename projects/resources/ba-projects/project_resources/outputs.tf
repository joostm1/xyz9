output "devops_entitlement" {
  value       = try(azuredevops_service_principal_entitlement.project_owner[0].descriptor, null)
  description = "Azure DevOps entitlement descriptor for this project's owner principal"
}
output "project_administrators_descriptor" {
  value = local.has_devops ? one(concat(
    data.azuredevops_group.project_administrators[*].descriptor,
    data.azuredevops_group.new_project_administrators[*].descriptor,
  )) : null
  description = "Project Administrators group of this project's Azure DevOps project"
}
