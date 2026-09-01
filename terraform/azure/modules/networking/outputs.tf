output "virtual_network_id" {
  description = "ID of the Azure virtual network."
  value       = azurerm_virtual_network.this.id
}

output "virtual_network_name" {
  description = "Name of the Azure virtual network."
  value       = azurerm_virtual_network.this.name
}

output "subnet_id" {
  description = "ID of the baseline workload subnet."
  value       = azurerm_subnet.compute.id
}

output "subnet_name" {
  description = "Name of the baseline workload subnet."
  value       = azurerm_subnet.compute.name
}

output "network_security_group_id" {
  description = "ID of the baseline compute Network Security Group."
  value       = azurerm_network_security_group.compute.id
}

output "network_security_group_name" {
  description = "Name of the baseline compute Network Security Group."
  value       = azurerm_network_security_group.compute.name
}
