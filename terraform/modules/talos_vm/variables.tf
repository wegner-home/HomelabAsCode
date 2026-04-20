variable "name" {
  description = "Name of the Talos VM"
  type        = string
}

variable "target_node" {
  description = "Proxmox node to create the VM on"
  type        = string
}

variable "cores" {
  description = "Number of CPU cores"
  type        = number
}

variable "memory" {
  description = "Amount of RAM in MB"
  type        = number
}

variable "ip_address" {
  description = "IP address for the VM (used for identification)"
  type        = string
}

variable "mac_address" {
  description = "MAC address for the VM network interface"
  type        = string
}

variable "bridge" {
  description = "Network bridge to use"
  type        = string
  default     = "vmbr0"
}

variable "iso_file" {
  description = "Path to Talos ISO file in Proxmox (e.g., 'local:iso/talos-amd64.iso')"
  type        = string
}

variable "disk_storage" {
  description = "Storage location for the VM disk"
  type        = string
  default     = "local-lvm"
}

variable "disk_size" {
  description = "Size of the primary disk"
  type        = string
  default     = "20G"
}

variable "additional_disks" {
  description = "Additional disks to attach to the VM"
  type = list(object({
    storage = string
    size    = string
  }))
  default = []
}

variable "ip_gateway" {
  description = "Gateway IP for static IP kernel parameter"
  type        = string
  default     = ""
}

variable "ip_cidr" {
  description = "CIDR prefix length (e.g., 24 for /24 subnet)"
  type        = string
  default     = "24"
}

variable "ip_dns" {
  description = "DNS servers for static IP kernel parameter"
  type        = list(string)
  default     = []
}

variable "hostname" {
  description = "Hostname for the VM (used in kernel ip= parameter)"
  type        = string
  default     = ""
}

variable "static_ip_kernel_param" {
  description = "Enable static IP via kernel boot parameter (disables DHCP at boot)"
  type        = bool
  default     = true
}
