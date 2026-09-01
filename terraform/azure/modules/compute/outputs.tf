output "virtual_machine_id" {
  description = "ID of the baseline Azure Linux VM."
  value       = azurerm_linux_virtual_machine.this.id
}

output "virtual_machine_name" {
  description = "Name of the baseline Azure Linux VM."
  value       = azurerm_linux_virtual_machine.this.name
}

output "virtual_machine_size" {
  description = "SKU of the baseline Azure Linux VM."
  value       = azurerm_linux_virtual_machine.this.size
}

output "private_ip_address" {
  description = "Private IPv4 address assigned to the Azure VM."
  value       = azurerm_network_interface.this.private_ip_address
}

output "network_interface_id" {
  description = "ID of the Azure VM network interface."
  value       = azurerm_network_interface.this.id
}

output "principal_id" {
  description = "Object ID of the system-assigned managed identity."
  value       = azurerm_linux_virtual_machine.this.identity[0].principal_id
}
