output "budget_id" {
  description = "ID of the Azure Resource Group consumption budget."
  value       = azurerm_consumption_budget_resource_group.this.id
}

output "budget_name" {
  description = "Name of the Azure Resource Group budget."
  value       = azurerm_consumption_budget_resource_group.this.name
}

output "monthly_limit" {
  description = "Configured Azure monthly budget."
  value       = var.monthly_limit
}
