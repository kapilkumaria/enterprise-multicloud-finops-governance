variable "aws_region" {
  description = "Approved AWS region for the dev environment."
  type        = string
  default     = "us-west-2"

  validation {
    condition     = contains(["us-east-1"], var.aws_region)
    error_message = "AWS region must be one of the approved Project 7 regions."
  }
}

variable "environment" {
  description = "Deployment environment."
  type        = string
  default     = "dev"

  validation {
    condition = contains([
      "sandbox",
      "dev",
      "staging",
      "production"
    ], var.environment)

    error_message = "Environment must be sandbox, dev, staging, or production."
  }
}

variable "aws_instance_type" {
  description = "AWS EC2 instance type used for the governed baseline workload."
  type        = string
  default     = "t3.micro"

  validation {
    condition = contains(
      [
        "t3.micro",
        "t3.small",
        "t3.medium"
      ],
      var.aws_instance_type
    )

    error_message = "AWS instance type must be an approved Project 7 instance type."
  }
}

variable "aws_root_volume_size" {
  description = "AWS EC2 root EBS volume size in GiB."
  type        = number
  default     = 8

  validation {
    condition     = var.aws_root_volume_size >= 8 && var.aws_root_volume_size <= 30
    error_message = "AWS root volume must be between 8 and 30 GiB."
  }
}

variable "aws_monthly_budget_usd" {
  description = "Monthly AWS FinOps budget guardrail in USD."
  type        = number
  default     = 25

  validation {
    condition     = var.aws_monthly_budget_usd >= 20
    error_message = "AWS monthly budget must be at least USD 20 for the current baseline."
  }
}

variable "aws_budget_notification_threshold_percent" {
  description = "Actual-cost percentage that triggers the AWS monthly budget notification."
  type        = number
  default     = 80

  validation {
    condition = (
      var.aws_budget_notification_threshold_percent > 0 &&
      var.aws_budget_notification_threshold_percent <= 100
    )

    error_message = "AWS budget notification threshold must be between 1 and 100."
  }
}

variable "aws_budget_notification_emails" {
  description = "Email recipients for AWS monthly budget notifications."
  type        = list(string)

  default = [
    "kapil.azure.lab@gmail.com"
  ]
}
