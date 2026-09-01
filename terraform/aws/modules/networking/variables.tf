variable "name_prefix" {
  description = "Name prefix for AWS networking resources."
  type        = string
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC."
  type        = string
  default     = "10.70.0.0/16"
}

variable "public_subnet_cidr" {
  description = "CIDR block for the public subnet."
  type        = string
  default     = "10.70.10.0/24"
}

variable "availability_zone" {
  description = "Availability Zone for the public subnet."
  type        = string
  default     = "us-east-1a"
}

variable "tags" {
  description = "Common tags applied to AWS resources."
  type        = map(string)
}
