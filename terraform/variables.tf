# Proxmox
variable "pm_api_uri" {
  description = "Proxmox Url"
  type        = string
}

variable "sops_secrets_file" {
  description = "Path to SOPS-encrypted secrets YAML containing vault_secrets"
  type        = string
  default     = null
  nullable    = true
}

variable "sops_runtime_file" {
  description = "Optional path to runtime SOPS YAML containing top-level proxmox credentials"
  type        = string
  default     = null
  nullable    = true
}

variable "proxmox_auth_node" {
  description = "Proxmox node key under vault_secrets.proxmox used for default provider auth"
  type        = string
  default     = "pve04"
}

variable "pm_api_token_id" {
  description = "Proxmox API Token ID"
  type        = string
  default     = null
  nullable    = true
  sensitive   = true
}
variable "pm_api_secret" {
  description = "Proxmox API Secret"
  type        = string
  default     = null
  nullable    = true
  sensitive   = true
}

#OPNsense
variable "opnsense_uri" {
  description = "The URI of the OPNsense server."
  type        = string
}
variable "opnsense_api_key" {
  description = "The API key for authenticating with the OPNsense server."
  type        = string
  default     = null
  nullable    = true
  sensitive   = true
}
variable "opnsense_api_secret" {
  description = "The API secret for authenticating with the OPNsense server."
  type        = string
  default     = null
  nullable    = true
  sensitive   = true
}

# Ressource: Subnets
variable "subnets" {
  description = "A map of subnets to create."
  type = map(object({
    subnet      = string
    description = optional(string)
    dns_servers = optional(list(string))
    routers     = optional(list(string))
    domain_name = optional(string)
    pools       = optional(set(string), [])
  }))
  default = {}
}

variable "subnets_ansible" {
  description = "Subnets generated from Ansible inventory (merged with subnets)"
  type = map(object({
    subnet      = string
    description = optional(string)
    dns_servers = optional(list(string))
    routers     = optional(list(string))
    gateway     = optional(string)
    domain_name = optional(string)
    pools       = optional(set(string), [])
  }))
  default = {}
}

variable "all_subnets" {
  description = "Effective subnet map used by Terraform. If set, overrides merge(subnets, subnets_ansible)."
  type = map(object({
    subnet      = string
    description = optional(string)
    dns_servers = optional(list(string))
    routers     = optional(list(string))
    gateway     = optional(string)
    domain_name = optional(string)
    pools       = optional(set(string), [])
  }))
  default = {}
}

# Ressource: Virtual Machines

variable "regular_vms" {
  type = map(object({
    name           = string
    target_node    = string
    clone_template = string
    # Resources - required
    cores  = number
    memory = number
    # Networking - recommended
    ip_address  = optional(string)
    mac_address = optional(string)
    cidr        = optional(string)
    subnet_key  = optional(string)

    # Networking - optionals
    bridge = optional(string)
    # Cloud-init - optionals
    ciuser               = optional(string)
    cipassword           = optional(string)
    ssh_key_files        = optional(list(string), [])
    cloud_init_user_data = optional(string, "")
    # Optional disks
    add_disk_space = optional(string, "0G")
    optional_disks = optional(list(object({
      storage = string
      size    = string
      slot    = optional(number)
    })), [])
  }))
  default = {}
}

variable "ansible_vms" {
  type = map(object({
    name           = string
    target_node    = string
    clone_template = string
    # Resources - required
    cores  = number
    memory = number
    # Networking - recommended
    ip_address  = optional(string)
    mac_address = optional(string)
    cidr        = optional(string)
    subnet_key  = optional(string)

    # Networking - optionals
    bridge  = optional(string)
    routers = optional(string)
    # Cloud-init - optionals
    ciuser               = optional(string)
    cipassword           = optional(string)
    ssh_key_files        = optional(list(string), [])
    cloud_init_user_data = optional(string, "")
    # Optional disks
    add_disk_space = optional(string, "0G")
    optional_disks = optional(list(object({
      storage = string
      size    = string
      slot    = optional(number)
    })), [])
  }))
  default = {}
}

# Ressource: NixOS VMs

variable "nixos_vms" {
  description = "Map of NixOS VMs to create"
  type = map(object({
    name           = string # VM name
    target_node    = string # Proxmox node (e.g., "pve05")
    clone_template = string # NixOS cloud-init template name

    # Resources
    cores   = number                 # CPU cores
    memory  = number                 # RAM in MB
    balloon = optional(number, 1024) # Minimum memory for ballooning. 0 to disable.

    # Networking
    ip_address  = string           # Static IP address
    mac_address = string           # MAC address
    cidr        = string           # CIDR prefix (e.g., "24")
    gateway     = optional(string) # Default gateway IP
    subnet_key  = string           # Reference to subnet in var.subnets

    # Cloud-Init
    ciuser     = optional(string, "admin")    # Default cloud-init user
    cipassword = optional(string, "changeme") # Default password (overridden by SSH keys)
    ssh_keys   = optional(list(string), [])   # Additional SSH public keys

    # Disk Management
    add_disk_space = optional(string, "0G") # Additional space beyond 5G base disk
    optional_disks = optional(list(object({
      storage = string # Storage pool (e.g., "local-lvm")
      size    = string # Disk size (e.g., "50G")
      slot    = optional(number)
    })), [])

    # NixOS-Specific
    homelab_role   = optional(string, "generic") # admin, gitlab, talos, generic
    nixos_channel  = optional(string, "25.11")   # NixOS channel version
    boot_disk_type = optional(string, "virtio")  # Boot disk type: 'scsi' or 'virtio'
    dns_hostnames  = optional(list(string), [])  # DNS aliases
  }))
  default = {}
}

variable "nixos_vms_ansible" {
  description = "NixOS VMs generated from Ansible inventory"
  type = map(object({
    name           = string
    target_node    = string
    clone_template = string
    cores          = number
    memory         = number
    balloon        = optional(number, 1024)
    ip_address     = string
    mac_address    = string
    cidr           = string
    gateway        = string
    subnet_key     = string
    ciuser         = optional(string, "admin")
    cipassword     = optional(string, "changeme")
    sshkeys        = optional(string, "")       # SSH public keys (newline-separated string)
    ssh_keys       = optional(list(string), []) # Kept for backwards compatibility
    add_disk_space = optional(string, "0G")
    optional_disks = optional(list(object({
      storage = string
      size    = string
      slot    = optional(number)
    })), [])
    homelab_role   = optional(string, "generic")
    nixos_channel  = optional(string, "25.11")
    boot_disk_type = optional(string, "virtio")
    # Additional fields from Ansible template
    hostname      = optional(string)
    dns_hostnames = optional(list(string), [])
    bridge        = optional(string, "vmbr0")
    dns_enabled   = optional(bool, true)
    dhcp_enabled  = optional(bool, true)
    description   = optional(string, "NixOS VM managed by Terraform")
    tags          = optional(list(string), ["nixos", "terraform", "ansible"])
    boot_order    = optional(string)
    onboot        = optional(bool, true)
  }))
  default = {}
}

# Ressource: Standalone Reservations (DNS and DHCP only)
variable "reservations" {
  description = "A map of standalone DNS and DHCP reservations for devices not managed by Terraform (e.g., external VMs, IoT devices)"
  type = map(object({
    hostname      = string       # Primary hostname (used for DHCP)
    dns_hostnames = list(string) # List of all DNS hostnames (can include primary + aliases)
    ip_address    = string
    mac_address   = string
    subnet_key    = string
    description   = optional(string, "")
    dns_enabled   = optional(bool, true)
    dhcp_enabled  = optional(bool, true)
  }))
  default = {}
}

variable "reservations_ansible" {
  description = "Standalone DNS/DHCP reservations generated from Ansible inventory (merged with reservations)"
  type = map(object({
    hostname      = string
    dns_hostnames = list(string)
    ip_address    = string
    mac_address   = string
    subnet_key    = string
    description   = optional(string, "")
    dns_enabled   = optional(bool, true)
    dhcp_enabled  = optional(bool, true)
  }))
  default = {}
}

# Global Configuration for NixOS VMs
variable "global_ssh_keys" {
  description = "SSH public keys to add to all VMs"
  type        = list(string)
  default     = []
}

variable "dns_domain" {
  description = "DNS domain for host overrides"
  type        = string
  default     = "example.lan"
}

variable "skip_dhcp_reservations" {
  description = "Skip creating OPNsense DHCP reservations (useful when they already exist outside Terraform state)"
  type        = bool
  default     = false
}

# =============================================
# Talos Kubernetes Cluster
# =============================================

variable "talos_cluster" {
  description = "Cluster-level settings for Talos K8s"
  type = object({
    enabled      = optional(bool, false)
    target_node  = optional(string, "pve05")
    target_nodes = optional(list(string), [])

    # Network
    subnet_key            = string
    cidr                  = string
    ip_gateway            = optional(string)
    ip_dns                = optional(list(string), [])
    ip_range_metallb      = optional(string, "")
    ip_range_controlplane = optional(string, "")
    ip_range_worker       = optional(string, "")

    # ISO
    iso_file    = string
    iso_storage = optional(string, "local")

    # Talos Factory
    download_iso      = optional(bool, false)
    talos_version     = optional(string, "v1.7.6")
    talos_arch        = optional(string, "amd64")
    talos_extensions  = optional(list(string), [])
    iso_download_path = optional(string, "/tmp")

    # Storage
    disk_storage = string
  })
  default = {
    enabled      = false
    subnet_key   = "kubernetes"
    cidr         = "16"
    iso_file     = "local:iso/talos-amd64.iso"
    disk_storage = "local-lvm"
  }
}

variable "talos_controlplane_nodes" {
  description = "Map of Talos control plane nodes"
  type = map(object({
    target_node  = string
    cores        = number
    memory       = number
    disk_size    = string
    disk_storage = string
    ip_address   = string
    mac_address  = string
    bridge       = optional(string, "vmbr0")
    iso_file     = string
  }))
  default = {}
}

variable "talos_worker_nodes" {
  description = "Map of Talos worker nodes"
  type = map(object({
    target_node  = string
    cores        = number
    memory       = number
    disk_size    = string
    disk_storage = string
    ip_address   = string
    mac_address  = string
    bridge       = optional(string, "vmbr0")
    iso_file     = string
  }))
  default = {}
}

variable "proxmox_node_ips" {
  description = "Map of Proxmox node names to their management IP addresses (used for SSH-based operations like ISO upload)"
  type        = map(string)
  default     = {}
}
