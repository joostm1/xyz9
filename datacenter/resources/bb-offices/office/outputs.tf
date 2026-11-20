output "config" {
  value = {
    name   = var.office.name
    router = local.router
    id     = local.me.id
    cert = {
      name = azurerm_key_vault_certificate.ipsec_cert.name
      id   = azurerm_key_vault_certificate.ipsec_cert.id
    }
  }
}
