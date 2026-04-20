variable "name" {
  type = string
}

variable "target_node" {
  type = string
}

variable "clone_template" {
  type = string
}

variable "cores" {
  type = number
}

variable "memory" {
  type = number
}

variable "ciuser" {
  type = string
}

variable "cipassword" {
  type = string
}

variable "ip_address" {
  type = string
}

variable "mac_address" {
  type = string
}

variable "cidr" {
  type = string
}

variable "bridge" {
  type    = string
  default = "vmbr0"
}

variable "ssh_key_files" {
  description = "DEPRECATED: Use sshkeys instead. List of SSH public key file paths."
  type        = list(string)
  default     = []
}

variable "balloon" {
  description = "Minimum memory in MB for ballooning. 0 to disable."
  type        = number
  default     = 1024
}

variable "sshkeys" {
  description = "SSH public keys for cloud-init (newline-separated string of public keys)"
  type        = string
  default     = ""
}

variable "cloud_init_user_data" {
  type    = string
  default = ""
}

variable "id" {
  type    = number
  default = 0
}

variable "optional_disks" {
  description = "List of optional disks to attach to the VM"
  type = list(object({
    storage = string
    size    = string
    slot    = optional(number)
  }))
  default = []
}

variable "routers" {
  type    = string
  default = ""
}

variable "add_disk_space" {
  description = "Additional disk space to add to the base 5G disk (e.g., '10G', '20G')"
  type        = string
  default     = "0G"
}

variable "use_cloud_init_snippet" {
  description = "Whether to use a custom cloud-init snippet file (not needed for NixOS)"
  type        = bool
  default     = false
}

variable "boot_disk_type" {
  description = "Boot disk interface type: 'scsi' or 'virtio'"
  type        = string
  default     = "virtio"
  validation {
    condition     = contains(["scsi", "virtio"], var.boot_disk_type)
    error_message = "boot_disk_type must be either 'scsi' or 'virtio'."
  }
}
