
locals {
  pemap = {
    vault       = "privatelink.vaultcore.azure.net"
    blob        = "privatelink.blob.core.windows.net"
    dfs         = "privatelink.dfs.core.windows.net"
    sql         = "privatelink.database.windows.net"
    sqlmi       = "privatelink.mssql.database.windows.net"
    file        = "privatelink.file.core.windows.net"
    queue       = "privatelink.queue.core.windows.net"
    eventgrid   = "privatelink.eventgrid.azure.net"
    appconfig   = "privatelink.azconfig.io"
    servicebus  = "privatelink.servicebus.windows.net"
    dataFactory = "privatelink.datafactory.azure.net"
  }
  pdnsProvider = "providers/Microsoft.Network/privateDnsZones"
  dnszone_ids = [for k in var.sub_resources :
    join("/", [var.dnszoneresourcegroup_id, local.pdnsProvider, local.pemap[k]])
  ]
  private_connection_resource       = trimspace(var.private_connection_resource)
  private_connection_resource_is_id = startswith(lower(local.private_connection_resource), "/subscriptions/")
  private_connection_resource_id    = local.private_connection_resource_is_id ? local.private_connection_resource : null
  private_connection_resource_alias = local.private_connection_resource_is_id ? null : local.private_connection_resource
}
variable "name" {
  type = string
}
variable "location" {
  type = string
}
variable "resource_group_name" {
  type = string
}
variable "subnet_id" {
  type = string
}
variable "sub_resources" {
  type = list(string)
}
variable "private_connection_resource" {
  type        = string
  description = "The resource ID or alias of the private link service target. Values starting with /subscriptions/ are treated as resource IDs; other values are treated as aliases."

  validation {
    condition     = length(trimspace(var.private_connection_resource)) > 0
    error_message = "private_connection_resource must be a non-empty string."
  }
}
variable "dnszoneresourcegroup_id" {
  type    = string
  default = "/subscriptions/98000b13-b691-416e-ad86-ef05d9227b9e/resourceGroups/rg-datacenter"
}
variable "is_manual_connection" {
  type    = bool
  default = false
}
variable "request_message" {
  type    = string
  default = "Please approve this private link connection."
}
resource "azurerm_private_endpoint" "this_pe" {
  name                          = var.name
  location                      = var.location
  resource_group_name           = var.resource_group_name
  subnet_id                     = var.subnet_id
  custom_network_interface_name = "${var.name}-nic"
  private_service_connection {
    name                              = "${var.name}-psc"
    private_connection_resource_id    = local.private_connection_resource_id
    private_connection_resource_alias = local.private_connection_resource_alias
    subresource_names                 = var.sub_resources
    is_manual_connection              = var.is_manual_connection
    request_message                   = var.is_manual_connection ? var.request_message : null
  }
  private_dns_zone_group {
    name                 = "${var.name}-pdnszg"
    private_dns_zone_ids = local.dnszone_ids
  }
}
output "id" {
  value = azurerm_private_endpoint.this_pe.id
}
output "address" {
  value = azurerm_private_endpoint.this_pe.private_service_connection[0].private_ip_address
}
# So you can refer to this in other resouces that depend on the private endpoint
output "private_connection_resource_id" {
  value = local.private_connection_resource_id
}
