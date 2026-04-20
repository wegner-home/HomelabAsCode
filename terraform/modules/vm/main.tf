locals {
  # Calculate total disk size for cloned disk resize
  # Template disk is 32G, add_disk_space adds to that
  disk_size = var.add_disk_space != "0G" ? "${parseint(replace(var.add_disk_space, "G", ""), 10) + 32}G" : "32G"
}

resource "proxmox_vm_qemu" "vm" {
  name        = var.name
  target_node = var.target_node
  clone       = var.clone_template
  full_clone  = true
  memory      = var.memory
  balloon     = var.balloon
  os_type     = "cloud-init"
  cicustom    = var.use_cloud_init_snippet ? "user=local:snippets/${var.name}-cloud-config.yml" : null
  ipconfig0   = "ip=${var.ip_address}/${var.cidr},gw=${var.routers}"
  # Boot order matches template: virtio0 or scsi0 for boot disk, ide2 for cloud-init
  boot        = "order=${var.boot_disk_type == "virtio" ? "virtio0" : "scsi0"};ide2"
  scsihw      = "virtio-scsi-pci"
  agent       = 1

  # Cloud-init user configuration
  ciuser     = var.ciuser
  cipassword = var.cipassword
  # SSH keys for cloud-init (newline-separated public keys)
  sshkeys    = var.sshkeys
  cpu {
    cores = var.cores
  }
  network {
    id      = 0
    model   = "virtio"
    macaddr = var.mac_address
    bridge  = "vmbr0"
  }

  # Most cloud-init images require a serial device for their display
  serial {
    id = 0
  }

  # IMPORTANT: When cloning a template, the boot disk is inherited from the template.
  # We only need to define the disk to resize it and ensure Terraform tracks it.
  # The disk comes from the clone - we're not creating a new disk, just specifying
  # how to resize the cloned disk.
  disks {
    # VirtIO boot disk (from cloned template) - most NixOS templates use virtio0
    dynamic "virtio" {
      for_each = var.boot_disk_type == "virtio" ? [1] : []
      content {
        virtio0 {
          disk {
            storage    = "local-lvm"
            size       = local.disk_size
            # Replicate from template - this tells Terraform the disk comes from clone
            replicate  = true
          }
        }
        # Optional additional disks on virtio (these are new disks, not cloned)
        dynamic "virtio1" {
          for_each = length(var.optional_disks) > 0 ? [var.optional_disks[0]] : []
          content {
            disk {
              storage = virtio1.value.storage
              size    = virtio1.value.size
            }
          }
        }
        dynamic "virtio2" {
          for_each = length(var.optional_disks) > 1 ? [var.optional_disks[1]] : []
          content {
            disk {
              storage = virtio2.value.storage
              size    = virtio2.value.size
            }
          }
        }
        dynamic "virtio3" {
          for_each = length(var.optional_disks) > 2 ? [var.optional_disks[2]] : []
          content {
            disk {
              storage = virtio3.value.storage
              size    = virtio3.value.size
            }
          }
        }
      }
    }

    # SCSI boot disk (from cloned template) - for templates using scsi0
    dynamic "scsi" {
      for_each = var.boot_disk_type == "scsi" ? [1] : []
      content {
        scsi0 {
          disk {
            storage    = "local-lvm"
            size       = local.disk_size
            # Replicate from template - this tells Terraform the disk comes from clone
            replicate  = true
          }
        }
        # Optional additional disks on scsi (these are new disks, not cloned)
        dynamic "scsi1" {
          for_each = length(var.optional_disks) > 0 ? [var.optional_disks[0]] : []
          content {
            disk {
              storage = scsi1.value.storage
              size    = scsi1.value.size
            }
          }
        }
        dynamic "scsi2" {
          for_each = length(var.optional_disks) > 1 ? [var.optional_disks[1]] : []
          content {
            disk {
              storage = scsi2.value.storage
              size    = scsi2.value.size
            }
          }
        }
        dynamic "scsi3" {
          for_each = length(var.optional_disks) > 2 ? [var.optional_disks[2]] : []
          content {
            disk {
              storage = scsi3.value.storage
              size    = scsi3.value.size
            }
          }
        }
      }
    }

    ide {
      # Cloud-init drive on ide2 (standard Proxmox convention, matches template)
      ide2 {
        cloudinit {
          storage = "local-lvm"
        }
      }
    }
  }
}
