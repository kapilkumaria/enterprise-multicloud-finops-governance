output "terraform_state_resource_group_name" {
  description = "Azure Resource Group containing the Terraform state backend."
  value       = azurerm_resource_group.terraform_state.name
}

output "terraform_state_storage_account_name" {
  description = "Azure Storage Account used for Terraform remote state."
  value       = azurerm_storage_account.terraform_state.name
}

output "terraform_state_container_name" {
  description = "Blob container used for Terraform remote state."
  value       = azurerm_storage_container.terraform_state.name
}

output "terraform_state_key" {
  description = "Recommended state key for the Azure dev environment."
  value       = "mc-finops/azure/dev/terraform.tfstate"
}

output "terraform_state_location" {
  description = "Azure region containing the Terraform state backend."
  value       = var.azure_location
}
