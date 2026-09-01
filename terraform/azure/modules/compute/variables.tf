variable "name_prefix" {
  description = "Name prefix for Azure compute resources."
  type        = string
}

variable "location" {
  description = "Azure region for compute resources."
  type        = string

  validation {
    condition     = lower(var.location) == "canadacentral"
    error_message = "Azure compute resources must be deployed in canadacentral."
  }
}

variable "resource_group_name" {
  description = "Resource group containing the baseline compute workload."
  type        = string
}

variable "subnet_id" {
  description = "Subnet ID used by the baseline Azure VM."
  type        = string
}

variable "vm_size" {
  description = "Azure VM SKU used by the baseline workload."
  type        = string
  default     = "Standard_B1s"
}

variable "admin_username" {
  description = "Local administrator username for the Linux VM."
  type        = string
  default     = "azureadmin"
}

variable "ssh_public_key" {
  description = "SSH public key used for the Linux administrator account."
  type        = string
  sensitive   = true
}

variable "tags" {
  description = "Common governance and FinOps tags."
  type        = map(string)
}
