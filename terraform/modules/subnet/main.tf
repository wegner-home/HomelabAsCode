resource "opnsense_kea_subnet" "subnets" {
  subnet      = var.subnet
  description = var.description
  dns_servers = var.dns_servers
  routers     = var.routers
  domain_name = var.domain_name
  pools       = var.pools
}