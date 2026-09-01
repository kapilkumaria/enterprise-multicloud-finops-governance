variable "name_prefix" {
  description = "Name prefix for AWS compute resources."
  type        = string
}

variable "subnet_id" {
  description = "Subnet ID where the EC2 instance will be deployed."
  type        = string
}

variable "security_group_id" {
  description = "Security Group attached to the EC2 instance."
  type        = string
}

variable "instance_type" {
  description = "EC2 instance type used by the baseline workload."
  type        = string
  default     = "t3.micro"
}

variable "root_volume_size" {
  description = "Root EBS volume size in GiB."
  type        = number
  default     = 8

  validation {
    condition     = var.root_volume_size >= 8 && var.root_volume_size <= 30
    error_message = "Root volume size must be between 8 and 30 GiB."
  }
}

variable "tags" {
  description = "Common tags applied to AWS compute resources."
  type        = map(string)
}
