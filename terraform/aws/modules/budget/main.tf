resource "aws_budgets_budget" "this" {
  name         = var.name
  budget_type  = "COST"
  limit_amount = tostring(var.monthly_limit_usd)
  limit_unit   = "USD"
  time_unit    = "MONTHLY"

  cost_filter {
    name = "TagKeyValue"

    values = [
      format(
        "user:Project$%s",
        var.project_name
      )
    ]
  }

  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = var.notification_threshold_percent
    threshold_type             = "PERCENTAGE"
    notification_type          = "ACTUAL"
    subscriber_email_addresses = var.notification_email_addresses
  }
}
