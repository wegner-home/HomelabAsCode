resource "opnsense_unbound_host_alias" "alias" {
  override    = var.override_id
  enabled     = var.enabled
  description = var.description

  hostname = var.hostname
  domain   = var.domain
}
