variable "aws_region" {
  description = "AWS region used for the Terraform remote-state backend."
  type        = string
  default     = "us-east-1"

  validation {
    condition     = contains(["us-east-1"], var.aws_region)
    error_message = "AWS region must be one of the approved Project 7 regions."
  }
}

variable "project_name" {
  description = "Project identifier used for naming."
  type        = string
  default     = "mc-finops"
}
