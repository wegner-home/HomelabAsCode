output "vm_id" {
  description = "The ID of the created Talos VM"
  value       = proxmox_vm_qemu.talos_vm.id
}

output "vm_name" {
  description = "The name of the created Talos VM"
  value       = proxmox_vm_qemu.talos_vm.name
}

output "ip_address" {
  description = "The desired IP address (from inventory — applied via talosctl)"
  value       = var.ip_address
}

output "actual_ip_address" {
  description = "The actual IP address reported by QEMU guest agent (DHCP-assigned in maintenance mode)"
  value       = proxmox_vm_qemu.talos_vm.default_ipv4_address
}

output "mac_address" {
  description = "The MAC address of the VM"
  value       = var.mac_address
}

output "ip_kernel_param" {
  description = "Kernel boot parameter for static IP (use with --extra-kernel-arg when building custom Talos ISO)"
  value       = local.ip_kernel_param
}

output "talos_factory_iso_command" {
  description = "Command to build custom Talos ISO with static IP using Talos Imager"
  value       = local.use_static_ip ? "docker run --rm -v $PWD/_out:/out ghcr.io/siderolabs/imager:v1.9.5 iso --arch amd64 --extra-kernel-arg '${local.ip_kernel_param}' --output-path /out" : ""
}
