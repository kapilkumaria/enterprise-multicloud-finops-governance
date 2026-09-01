variable "azure_location" {
  description = "Approved Azure location for the dev environment."
  type        = string
  default     = "canadacentral"

  validation {
    condition     = contains(["canadacentral"], lower(var.azure_location))
    error_message = "Azure location must be one of the approved Project 7 regions."
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
