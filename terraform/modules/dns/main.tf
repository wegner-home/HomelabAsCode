resource "opnsense_unbound_host_override" "dns_reservations" {
  enabled     = var.enabled
  description = var.description

  hostname = var.hostname
  domain   = var.domain
  server   = var.ip_address
}