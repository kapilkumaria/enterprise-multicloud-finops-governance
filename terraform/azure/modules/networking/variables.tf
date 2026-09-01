variable "name_prefix" {
  description = "Name prefix for Azure networking resources."
  type        = string
}

variable "resource_group_name" {
  description = "Name of the Azure resource group."
  type        = string
}

variable "location" {
  description = "Azure region for networking resources."
  type        = string
}

variable "vnet_address_space" {
  description = "Address space for the Azure virtual network."
  type        = list(string)
  default     = ["10.80.0.0/16"]
}

variable "subnet_address_prefixes" {
  description = "Address prefixes for the baseline workload subnet."
  type        = list(string)
  default     = ["10.80.10.0/24"]
}

variable "tags" {
  description = "Common tags applied to Azure networking resources."
  type        = map(string)
}
