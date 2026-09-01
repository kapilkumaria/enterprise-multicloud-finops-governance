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
