variable "hostname" {
  type = string
}

variable "ip_address" {
  type = string
}
variable "domain" {
  type = string
}
variable "enabled" {
  type    = bool
  default = true
}
variable "description" {
  type    = string
  default = "Managed by Terraform"
}