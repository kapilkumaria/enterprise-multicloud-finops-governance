output "environment" {
  description = "Azure Terraform environment."
  value       = var.environment
}

output "azure_location" {
  description = "Approved Azure deployment location."
  value       = var.azure_location
}

output "project_name" {
  description = "Project identifier."
  value       = local.project_name
}

output "resource_group_name" {
  description = "Azure dev resource group name."
  value       = azurerm_resource_group.dev.name
}

output "resource_group_id" {
  description = "Azure dev resource group ID."
  value       = azurerm_resource_group.dev.id
}

output "virtual_network_id" {
  description = "ID of the Azure dev virtual network."
  value       = module.networking.virtual_network_id
}

output "virtual_network_name" {
  description = "Name of the Azure dev virtual network."
  value       = module.networking.virtual_network_name
}

output "subnet_id" {
  description = "ID of the Azure dev compute subnet."
  value       = module.networking.subnet_id
}

output "subnet_name" {
  description = "Name of the Azure dev compute subnet."
  value       = module.networking.subnet_name
}

output "network_security_group_id" {
  description = "ID of the Azure dev compute Network Security Group."
  value       = module.networking.network_security_group_id
}

output "network_security_group_name" {
  description = "Name of the Azure dev compute Network Security Group."
  value       = module.networking.network_security_group_name
}

output "baseline_vm_id" {
  description = "ID of the Azure baseline Linux VM."
  value       = module.compute.virtual_machine_id
}

output "baseline_vm_name" {
  description = "Name of the Azure baseline Linux VM."
  value       = module.compute.virtual_machine_name
}

output "baseline_vm_size" {
  description = "Azure VM SKU used for the baseline workload."
  value       = module.compute.virtual_machine_size
}

output "baseline_vm_private_ip" {
  description = "Private IPv4 address of the Azure baseline VM."
  value       = module.compute.private_ip_address
}

output "baseline_vm_managed_identity_principal_id" {
  description = "Principal ID of the Azure baseline VM managed identity."
  value       = module.compute.principal_id
}
