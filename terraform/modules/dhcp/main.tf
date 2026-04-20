resource "opnsense_kea_reservation" "vm_reservations" {
  description = "Managed by Terraform: ${var.hostname}"
  hostname    = var.hostname
  ip_address  = var.ip_address
  mac_address = var.mac_address
  subnet_id   = var.subnet_id
}