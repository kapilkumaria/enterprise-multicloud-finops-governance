resource "azurerm_consumption_budget_resource_group" "this" {
  name              = var.name
  resource_group_id = var.resource_group_id

  amount     = var.monthly_limit
  time_grain = "Monthly"

  time_period {
    start_date = var.start_date
  }

  notification {
    enabled        = true
    threshold      = var.notification_threshold_percent
    operator       = "GreaterThanOrEqualTo"
    threshold_type = "Actual"

    contact_emails = var.notification_contact_emails
  }
}
