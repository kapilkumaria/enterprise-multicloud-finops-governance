variable "aws_region" {
  description = "Approved AWS region for the dev environment."
  type        = string
  default     = "us-east-1"

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
