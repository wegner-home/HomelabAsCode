output "subnet_ids" {
  value = { for k, v in module.subnets : k => v.subnet_id }
}

output "dhcp_ids" {
  value = { for k, v in module.dhcp_reservations : k => v.dhcp_id }
}

output "dns_ids" {
  value = { for k, v in module.dns_reservations : k => v.dns_id }
}

output "vm_ids" {
  value = { for k, v in module.vm : k => v.vm_id }
}

output "nixos_vm_ids" {
  value = { for k, v in module.nixos_vm : k => v.vm_id }
}

output "nixos_vms_summary" {
  description = "Summary of deployed NixOS VMs with key information"
  value = {
    for k, v in local.nixos_vms : k => {
      ip_address   = v.ip_address
      target_node  = v.target_node
      homelab_role = v.homelab_role
      vm_id        = module.nixos_vm[k].vm_id
    }
  }
}

output "nixos_vms_by_role" {
  description = "NixOS VMs grouped by homelab_role"
  value = {
    for role in distinct([for v in local.nixos_vms : v.homelab_role]) :
    role => {
      for k, v in local.nixos_vms : k => {
        ip_address  = v.ip_address
        target_node = v.target_node
        vm_id       = module.nixos_vm[k].vm_id
      }
      if v.homelab_role == role
    }
  }
}

# =============================================
# Talos K8s Outputs (static)
# =============================================
# Per-node Talos VM outputs and talos_iso_filename are
# auto-generated in talos-outputs.auto.tf

output "talos_dns_ids" {
  description = "DNS record IDs for Talos nodes"
  value       = { for k, v in module.talos_dns_reservations : k => v.dns_id }
}

output "talos_dhcp_ids" {
  description = "DHCP reservation IDs for Talos nodes"
  value       = { for k, v in module.talos_dhcp_reservations : k => v.dhcp_id }
}
