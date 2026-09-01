output "environment" {
  description = "AWS Terraform environment."
  value       = var.environment
}

output "aws_region" {
  description = "Approved AWS deployment region."
  value       = var.aws_region
}

output "project_name" {
  description = "Project identifier."
  value       = local.project_name
}
