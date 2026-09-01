output "budget_name" {
  description = "Name of the AWS monthly cost budget."
  value       = aws_budgets_budget.this.name
}

output "monthly_limit_usd" {
  description = "Configured AWS monthly budget limit."
  value       = var.monthly_limit_usd
}
