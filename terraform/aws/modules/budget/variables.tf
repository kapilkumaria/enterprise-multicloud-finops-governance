variable "name" {
  description = "Name of the AWS monthly cost budget."
  type        = string
}

variable "monthly_limit_usd" {
  description = "Monthly AWS cost budget in USD."
  type        = number

  validation {
    condition     = var.monthly_limit_usd > 0
    error_message = "AWS monthly budget must be greater than zero."
  }
}

variable "project_name" {
  description = "Project tag value used to scope the AWS budget."
  type        = string
}

variable "notification_threshold_percent" {
  description = "Actual-cost percentage that triggers the AWS budget notification."
  type        = number
  default     = 80

  validation {
    condition = (
      var.notification_threshold_percent > 0 &&
      var.notification_threshold_percent <= 100
    )

    error_message = "AWS budget notification threshold must be between 1 and 100."
  }
}

variable "notification_email_addresses" {
  description = "Email recipients for AWS budget notifications."
  type        = list(string)

  validation {
    condition     = length(var.notification_email_addresses) > 0
    error_message = "At least one AWS budget notification email is required."
  }
}
