variable "azure_location" {
  description = "Azure region used for the Terraform remote-state backend."
  type        = string
  default     = "canadacentral"

  validation {
    condition     = contains(["canadacentral"], lower(var.azure_location))
    error_message = "Azure location must be one of the approved Project 7 regions."
  }
}

variable "project_name" {
  description = "Short project identifier used for naming."
  type        = string
  default     = "mc-finops"
}
