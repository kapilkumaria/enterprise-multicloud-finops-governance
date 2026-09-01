output "environment" {
  description = "AWS Terraform environment."
  value       = var.environment
}

output "aws_region" {
  description = "Approved AWS deployment region."
  value       = var.aws_region
}

output "project_name" {
  description = "Project identifier."
  value       = local.project_name
}

output "vpc_id" {
  description = "AWS VPC ID for the dev environment."
  value       = module.networking.vpc_id
}

output "public_subnet_id" {
  description = "AWS public subnet ID for the dev environment."
  value       = module.networking.public_subnet_id
}

output "security_group_id" {
  description = "AWS baseline compute security group ID."
  value       = module.networking.security_group_id
}

output "internet_gateway_id" {
  description = "AWS Internet Gateway ID."
  value       = module.networking.internet_gateway_id
}

output "public_route_table_id" {
  description = "AWS public route table ID."
  value       = module.networking.public_route_table_id
}

output "vpc_flow_log_id" {
  description = "AWS VPC Flow Log ID."
  value       = module.networking.vpc_flow_log_id
}

output "vpc_flow_log_group_name" {
  description = "CloudWatch Log Group used for AWS VPC Flow Logs."
  value       = module.networking.vpc_flow_log_group_name
}

output "baseline_instance_id" {
  description = "AWS baseline EC2 instance ID."
  value       = module.compute.instance_id
}

output "baseline_instance_type" {
  description = "AWS baseline EC2 instance type."
  value       = module.compute.instance_type
}

output "baseline_instance_private_ip" {
  description = "Private IP address of the AWS baseline EC2 instance."
  value       = module.compute.private_ip
}

output "baseline_instance_ami_id" {
  description = "AMI used by the AWS baseline EC2 instance."
  value       = module.compute.ami_id
  sensitive   = true
}
