variable "name" {
  description = "Name of the Azure resource group budget."
  type        = string
}

variable "resource_group_id" {
  description = "Azure Resource Group ID to which the budget applies."
  type        = string
}

variable "monthly_limit" {
  description = "Monthly Azure budget amount."
  type        = number

  validation {
    condition     = var.monthly_limit > 0
    error_message = "Azure monthly budget must be greater than zero."
  }
}

variable "start_date" {
  description = "Budget start date. Azure requires the first day of a month."
  type        = string
}

variable "notification_threshold_percent" {
  description = "Percentage of the monthly budget that triggers the Azure notification."
  type        = number
  default     = 80

  validation {
    condition = (
      var.notification_threshold_percent > 0 &&
      var.notification_threshold_percent <= 100
    )

    error_message = "Azure budget notification threshold must be between 1 and 100."
  }
}

variable "notification_contact_emails" {
  description = "Email recipients for Azure budget notifications."
  type        = list(string)

  validation {
    condition     = length(var.notification_contact_emails) > 0
    error_message = "At least one Azure budget notification email is required."
  }
}
