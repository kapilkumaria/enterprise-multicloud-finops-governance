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

variable "vnet_address_space" {
  description = "Address space for the Azure dev virtual network."
  type        = list(string)
  default     = ["10.80.0.0/16"]
}

variable "subnet_address_prefixes" {
  description = "Address prefixes for the Azure dev compute subnet."
  type        = list(string)
  default     = ["10.80.10.0/24"]
}

variable "azure_vm_size" {
  description = "Azure VM SKU used for the baseline cost workload."
  type        = string
  default     = "Standard_B1s"
}

variable "azure_admin_username" {
  description = "Administrator username for the baseline Azure Linux VM."
  type        = string
  default     = "azureadmin"
}

variable "azure_ssh_public_key" {
  description = "SSH public key used by the baseline Azure Linux VM."
  type        = string
  sensitive   = true
}
