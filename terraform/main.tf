locals {
  # Merge all regular VM definitions (non-Talos)
  vms = merge(var.regular_vms, var.ansible_vms)

  # Merge all NixOS VM definitions
  nixos_vms = merge(var.nixos_vms, var.nixos_vms_ansible)

  # NixOS DNS: one primary override per VM (keyed by VM name),
  # plus alias entries for any additional dns_hostnames.
  nixos_dns_aliases = flatten([
    for k, v in local.nixos_vms : [
      for hn in try(v.dns_hostnames, []) : {
        key      = "${k}-${hn}"
        hostname = hn
        vm_name  = k
        role     = try(v.homelab_role, "generic")
      } if hn != k # skip if alias matches VM name (already the primary)
    ]
  ])

  # All VMs for DHCP reservations (including NixOS VMs) - DNS handled separately
  all_vms = merge(local.vms, local.nixos_vms)

  # Effective subnet definitions.
  # Prefer explicit all_subnets when provided, otherwise merge manual + Ansible-generated.
  all_subnets = length(var.all_subnets) > 0 ? var.all_subnets : merge(var.subnets, var.subnets_ansible)

  # Merge all standalone reservations (manual + Ansible-generated)
  all_reservations = merge(var.reservations, var.reservations_ansible)
}

module "subnets" {
  source      = "./modules/subnet"
  for_each    = local.all_subnets
  subnet      = each.value.subnet
  description = each.value.description
  dns_servers = each.value.dns_servers
  routers     = each.value.routers
  domain_name = each.value.domain_name
  pools       = each.value.pools
}

module "dns_reservations" {
  source      = "./modules/dns"
  for_each    = local.vms
  enabled     = true
  description = "Managed by Terraform: ${each.key}"
  domain      = var.dns_domain
  ip_address  = each.value.ip_address
  hostname    = each.key
}

# Primary DNS override per NixOS VM (one A record per VM name)
module "nixos_dns_reservations" {
  source      = "./modules/dns"
  for_each    = local.nixos_vms
  enabled     = true
  description = "Managed by Terraform: ${each.key} (NixOS ${try(each.value.homelab_role, "generic")})"
  domain      = var.dns_domain
  ip_address  = each.value.ip_address
  hostname    = each.key
}

# DNS aliases for additional hostnames (CNAME-like, linked to primary override)
module "nixos_dns_aliases" {
  source      = "./modules/dns_alias"
  for_each    = { for entry in local.nixos_dns_aliases : entry.key => entry }
  override_id = module.nixos_dns_reservations[each.value.vm_name].dns_id
  enabled     = true
  description = "Managed by Terraform: ${each.value.vm_name} alias (NixOS ${each.value.role})"
  domain      = var.dns_domain
  hostname    = each.value.hostname
}

module "dhcp_reservations" {
  source      = "./modules/dhcp"
  for_each    = local.all_vms
  hostname    = each.key
  ip_address  = each.value.ip_address
  mac_address = each.value.mac_address
  subnet_id   = module.subnets[each.value.subnet_key].subnet_id
}

module "vm" {
  for_each       = local.vms
  source         = "./modules/vm"
  name           = each.key
  target_node    = each.value.target_node
  clone_template = each.value.clone_template
  # Resources - required
  cores  = each.value.cores
  memory = each.value.memory
  # Networking - recommended
  ip_address  = each.value.ip_address
  mac_address = each.value.mac_address
  cidr        = each.value.cidr
  # Optionals
  bridge = each.value.bridge
  # Cloud-init - optional
  ciuser     = each.value.ciuser
  cipassword = each.value.cipassword
  # SSH keys - join key file contents for sshkeys string
  sshkeys              = join("\n", [for f in each.value.ssh_key_files : file(f)])
  cloud_init_user_data = each.value.cloud_init_user_data
  # Optional disks
  add_disk_space = each.value.add_disk_space != null ? each.value.add_disk_space : "0G"
  optional_disks = lookup(each.value, "optional_disks", [])
  routers        = "10.10.100.1" # Example static router; replace with dynamic lookup if needed
}

# NixOS VMs
module "nixos_vm" {
  for_each       = local.nixos_vms
  source         = "./modules/vm"
  name           = each.key
  target_node    = each.value.target_node
  clone_template = each.value.clone_template
  # Resources - required
  cores   = each.value.cores
  memory  = each.value.memory
  balloon = lookup(each.value, "balloon", 1024)
  # Networking - recommended
  ip_address  = each.value.ip_address
  mac_address = each.value.mac_address
  cidr        = each.value.cidr
  routers     = each.value.gateway
  # Optionals
  bridge = lookup(each.value, "bridge", null)
  # Cloud-init - required for NixOS
  ciuser     = each.value.ciuser
  cipassword = each.value.cipassword
  # SSH Keys - Use sshkeys string directly, or join global + VM-specific keys
  sshkeys = lookup(each.value, "sshkeys", "") != "" ? each.value.sshkeys : join("\n", concat(
    var.global_ssh_keys,
    lookup(each.value, "ssh_keys", [])
  ))
  cloud_init_user_data = ""
  # Optional disks
  add_disk_space = each.value.add_disk_space
  optional_disks = each.value.optional_disks
  # Boot disk type (scsi or virtio)
  boot_disk_type = lookup(each.value, "boot_disk_type", "virtio")
}


# Standalone DNS: primary override per reservation (one A record per device)
module "standalone_dns_reservations" {
  source      = "./modules/dns"
  for_each    = { for k, v in local.all_reservations : k => v if v.dns_enabled }
  enabled     = true
  description = each.value.description != "" ? each.value.description : "Managed by Terraform: ${each.key}"
  domain      = var.dns_domain
  ip_address  = each.value.ip_address
  hostname    = each.value.hostname
}

# Standalone DNS aliases for additional hostnames beyond the primary
module "standalone_dns_aliases" {
  source = "./modules/dns_alias"
  for_each = {
    for item in flatten([
      for k, v in local.all_reservations : [
        for hn in v.dns_hostnames : {
          key      = "${k}-${hn}"
          vm_name  = k
          hostname = hn
        } if hn != v.hostname && v.dns_enabled
      ]
    ]) : item.key => item
  }
  override_id = module.standalone_dns_reservations[each.value.vm_name].dns_id
  enabled     = true
  description = "Managed by Terraform: ${each.value.vm_name} alias"
  domain      = var.dns_domain
  hostname    = each.value.hostname
}

# Standalone DHCP reservations (for external devices, manual + Ansible-generated)
module "standalone_dhcp_reservations" {
  source      = "./modules/dhcp"
  for_each    = var.skip_dhcp_reservations ? {} : { for k, v in local.all_reservations : k => v if v.dhcp_enabled }
  hostname    = each.value.hostname
  ip_address  = each.value.ip_address
  mac_address = each.value.mac_address
  subnet_id   = module.subnets[each.value.subnet_key].subnet_id
}

# =============================================
# Talos Kubernetes Cluster — ISO + DNS/DHCP
# =============================================
# VM module blocks are auto-generated per Proxmox node in talos-nodes.auto.tf
# Per-node provider aliases are auto-generated in talos-providers.auto.tf
# Per-node outputs are auto-generated in talos-outputs.auto.tf

locals {
  # --- Talos ISO naming ---
  talos_iso_filename   = "talos-${var.talos_cluster.talos_version}-${var.talos_cluster.talos_arch}${length(var.talos_cluster.talos_extensions) > 0 ? "-custom" : ""}.iso"
  talos_iso_local_path = "${var.talos_cluster.iso_download_path}/${local.talos_iso_filename}"

  talos_factory_extensions_json = jsonencode({
    customization = {
      systemExtensions = {
        officialExtensions = sort(var.talos_cluster.talos_extensions)
      }
    }
  })

  # All unique Proxmox target nodes that host Talos VMs
  talos_all_target_nodes = var.talos_cluster.enabled ? distinct(
    concat(
      length(var.talos_cluster.target_nodes) > 0 ? var.talos_cluster.target_nodes : [],
      [for n in var.talos_controlplane_nodes : n.target_node],
      [for n in var.talos_worker_nodes : n.target_node]
    )
  ) : []

  # Resolved ISO path for Factory-downloaded ISOs (overrides per-node iso_file)
  _resolved_iso = var.talos_cluster.download_iso ? "${var.talos_cluster.iso_storage}:iso/${local.talos_iso_filename}" : null

  # Merge all Talos nodes for DNS/DHCP registration
  talos_all_nodes = merge(var.talos_controlplane_nodes, var.talos_worker_nodes)
}

# --- Talos Factory ISO download ---
resource "null_resource" "talos_iso_download" {
  count = var.talos_cluster.enabled && var.talos_cluster.download_iso ? 1 : 0

  triggers = {
    talos_version    = var.talos_cluster.talos_version
    talos_arch       = var.talos_cluster.talos_arch
    talos_extensions = join(",", sort(var.talos_cluster.talos_extensions))
  }

  provisioner "local-exec" {
    command = <<-EOT
      set -euo pipefail

      echo "=== Talos Factory ISO Download ==="
      echo "Version:    ${var.talos_cluster.talos_version}"
      echo "Arch:       ${var.talos_cluster.talos_arch}"
      echo "Extensions: ${join(", ", var.talos_cluster.talos_extensions)}"

      mkdir -p ${var.talos_cluster.iso_download_path}

      # Step 1: Get schematic ID from Talos Factory
      echo "Requesting schematic ID from factory.talos.dev..."
      SCHEMATIC_RESPONSE=$(curl -s -X POST https://factory.talos.dev/schematics \
        -H 'Content-Type: application/json' \
        -d '${local.talos_factory_extensions_json}')

      SCHEMATIC_ID=$(echo "$SCHEMATIC_RESPONSE" | grep -o '"id":"[^"]*"' | cut -d'"' -f4)

      if [ -z "$SCHEMATIC_ID" ]; then
        echo "ERROR: Failed to get schematic ID from factory"
        echo "Response: $SCHEMATIC_RESPONSE"
        exit 1
      fi
      echo "Schematic ID: $SCHEMATIC_ID"

      # Step 2: Download ISO using schematic ID
      ISO_URL="https://factory.talos.dev/image/$SCHEMATIC_ID/${var.talos_cluster.talos_version}/metal-${var.talos_cluster.talos_arch}.iso"
      echo "Downloading ISO from: $ISO_URL"

      curl -L -f -o ${local.talos_iso_local_path} "$ISO_URL"

      ISO_SIZE=$(du -h ${local.talos_iso_local_path} | cut -f1)
      echo "ISO downloaded: ${local.talos_iso_local_path} ($ISO_SIZE)"

      # Sanity check — ISO should be >50MB
      ISO_BYTES=$(stat -c%s ${local.talos_iso_local_path})
      if [ "$ISO_BYTES" -lt 50000000 ]; then
        echo "ERROR: ISO too small ($ISO_BYTES bytes) — download likely failed"
        rm -f ${local.talos_iso_local_path}
        exit 1
      fi
      echo "=== Download complete ==="
    EOT
  }

  provisioner "local-exec" {
    when    = destroy
    command = "echo 'Note: Talos ISO not auto-removed on destroy'"
  }
}

# --- Upload ISO to each Proxmox node hosting Talos VMs ---
resource "null_resource" "talos_iso_upload" {
  for_each = var.talos_cluster.enabled && var.talos_cluster.download_iso ? toset(local.talos_all_target_nodes) : []

  triggers = {
    iso_file         = local.talos_iso_local_path
    talos_version    = var.talos_cluster.talos_version
    talos_arch       = var.talos_cluster.talos_arch
    talos_extensions = join(",", sort(var.talos_cluster.talos_extensions))
    target_node      = each.key
  }

  depends_on = [null_resource.talos_iso_download]

  provisioner "local-exec" {
    command = <<-EOT
      set -euo pipefail
      SSH_OPTS="-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR -i /var/local/homelab/ssh/users/phil/id_ed25519"
      NODE_HOST="${lookup(var.proxmox_node_ips, each.key, each.key)}"
      echo "Uploading Talos ISO to Proxmox node: ${each.key} ($NODE_HOST)"
      echo "Target: ${each.key}:local:iso/${local.talos_iso_filename}"

      # Check if ISO already exists and matches
      if ssh $SSH_OPTS root@$NODE_HOST "test -f /var/lib/vz/template/iso/${local.talos_iso_filename}"; then
        echo "ISO already exists on ${each.key}, checking if update needed..."
        REMOTE_SIZE=$(ssh $SSH_OPTS root@$NODE_HOST "stat -c%s /var/lib/vz/template/iso/${local.talos_iso_filename}")
        LOCAL_SIZE=$(stat -c%s ${local.talos_iso_local_path})
        if [ "$REMOTE_SIZE" = "$LOCAL_SIZE" ]; then
          echo "ISO is up to date on ${each.key}"
          exit 0
        fi
        echo "ISO size differs, uploading new version..."
      fi

      echo "Starting upload ($(du -h ${local.talos_iso_local_path} | cut -f1))..."
      scp $SSH_OPTS ${local.talos_iso_local_path} root@$NODE_HOST:/var/lib/vz/template/iso/${local.talos_iso_filename}

      echo "ISO successfully uploaded to ${each.key}"
    EOT
  }

  provisioner "local-exec" {
    when    = destroy
    command = "echo 'Note: Talos ISO not auto-removed from Proxmox on destroy'"
  }
}

# --- Talos DNS reservations ---
module "talos_dns_reservations" {
  source      = "./modules/dns"
  for_each    = var.talos_cluster.enabled ? local.talos_all_nodes : {}
  enabled     = true
  description = "Managed by Terraform: ${each.key} (Talos K8s)"
  domain      = var.dns_domain
  ip_address  = each.value.ip_address
  hostname    = each.key
}

# --- Talos DHCP reservations ---
module "talos_dhcp_reservations" {
  source      = "./modules/dhcp"
  for_each    = var.skip_dhcp_reservations ? {} : (var.talos_cluster.enabled ? local.talos_all_nodes : {})
  hostname    = each.key
  ip_address  = each.value.ip_address
  mac_address = each.value.mac_address
  subnet_id   = module.subnets[var.talos_cluster.subnet_key].subnet_id
}
