output "subnet_id" {
  description = "The ID of the created subnet."
  value       = opnsense_kea_subnet.subnets.id
}
