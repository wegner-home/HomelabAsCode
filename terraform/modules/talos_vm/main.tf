# =============================================
# Static IP Kernel Parameter Generation
# =============================================
# Format: ip=<client-ip>:<srv-ip>:<gw-ip>:<netmask>:<hostname>:<device>:<autoconf>:<dns0>:<dns1>
# Example: ip=10.90.10.1::10.10.100.1:24:talos-cp-01:eth0:off:10.10.100.1::
# The 'off' for autoconf disables DHCP at boot time.
# Reference: https://docs.siderolabs.com/talos/v1.9/reference/kernel/#ip
#
# IMPORTANT: This uses Proxmox 'args' to pass QEMU arguments.
# Since Talos boots from GRUB in the ISO, we cannot inject kernel args directly.
#
# OPTIONS FOR STATIC IP AT BOOT:
# 1. Create per-node custom ISO with baked-in ip= kernel param (most reliable)
# 2. Use talosctl apply-config immediately after boot with static IP config
# 3. Ensure DHCP reservation is working (MAC must match exactly)
#
# This module outputs the kernel parameter string that can be used to:
# - Generate custom ISOs via Talos Image Factory
# - Be applied via talosctl machineconfig patch
# =============================================
locals {
  # Build the ip= kernel parameter for static IP assignment at boot
  # Only used when static_ip_kernel_param is enabled and gateway is provided
  use_static_ip = var.static_ip_kernel_param && var.ip_gateway != ""

  # Hostname for kernel param (fallback to VM name if not provided)
  kernel_hostname = var.hostname != "" ? var.hostname : var.name

  # DNS servers (up to 2 supported in kernel param)
  dns0 = length(var.ip_dns) > 0 ? var.ip_dns[0] : ""
  dns1 = length(var.ip_dns) > 1 ? var.ip_dns[1] : ""

  # Build the complete ip= kernel parameter
  # Format: ip=<client-ip>:<srv-ip>:<gw-ip>:<netmask>:<hostname>:<device>:<autoconf>:<dns0>:<dns1>
  ip_kernel_param = local.use_static_ip ? "ip=${var.ip_address}::${var.ip_gateway}:${var.ip_cidr}:${local.kernel_hostname}:eth0:off:${local.dns0}:${local.dns1}" : ""
}

resource "proxmox_vm_qemu" "talos_vm" {
  name        = var.name
  target_node = var.target_node
  memory      = var.memory

  # QEMU guest agent — Talos ISO includes qemu-guest-agent extension,
  # so Proxmox can query the actual IP (needed before talosctl apply-config)
  agent     = 1
  skip_ipv6 = true

  # Boot order: disk first, ISO fallback.
  # First boot: disk is empty → falls through to ISO → Talos maintenance mode.
  # After talosctl apply-config installs to disk → reboot → boots from disk.
  boot               = "order=scsi0;ide2"
  scsihw             = "virtio-scsi-pci"
  start_at_node_boot = true
  vm_state           = "running"

  # CPU configuration
  cpu {
    cores = var.cores
    type  = "host"
  }

  # Network configuration
  network {
    id      = 0
    model   = "virtio"
    macaddr = var.mac_address
    bridge  = var.bridge
  }

  # Serial console for Talos
  serial {
    id   = 0
    type = "socket"
  }

  # Disk configuration
  disks {
    scsi {
      scsi0 {
        disk {
          storage = var.disk_storage
          size    = var.disk_size
        }
      }

      # Additional disks for storage/etcd if needed
      dynamic "scsi1" {
        for_each = var.additional_disks
        content {
          disk {
            storage = scsi1.value.storage
            size    = scsi1.value.size
          }
        }
      }
    }

    # IDE for ISO
    ide {
      ide2 {
        cdrom {
          iso = var.iso_file
        }
      }
    }
  }

  # Use default VGA (std) — serial0 prevents SeaBIOS from finding bootable devices.
  # Talos console is accessible via Proxmox noVNC or serial terminal after boot.
  vga {
    type = "std"
  }
}
