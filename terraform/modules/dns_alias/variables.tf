variable "override_id" {
  description = "ID of the parent host override to attach this alias to"
  type        = string
}

variable "hostname" {
  description = "Alias hostname (without domain)"
  type        = string
}

variable "domain" {
  description = "Domain for the alias"
  type        = string
}

variable "enabled" {
  type    = bool
  default = true
}

variable "description" {
  type    = string
  default = "Managed by Terraform"
}
