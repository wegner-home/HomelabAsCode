variable "subnet" {
  type = string
}
variable "description" {
  type    = string
  default = ""
}
variable "dns_servers" {
  type    = list(string)
  default = []
}
variable "routers" {
  type    = list(string)
  default = []
}
variable "domain_name" {
  type    = string
  default = ""
}
variable "pools" {
  type    = set(string)
  default = []
}