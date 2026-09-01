output "instance_id" {
  description = "ID of the baseline EC2 instance."
  value       = aws_instance.this.id
}

output "instance_arn" {
  description = "ARN of the baseline EC2 instance."
  value       = aws_instance.this.arn
}

output "instance_type" {
  description = "Instance type used by the baseline EC2 workload."
  value       = aws_instance.this.instance_type
}

output "private_ip" {
  description = "Private IPv4 address of the baseline EC2 instance."
  value       = aws_instance.this.private_ip
}

output "ami_id" {
  description = "Amazon Linux 2023 AMI used by the baseline instance."
  value       = aws_instance.this.ami
}

output "iam_role_name" {
  description = "IAM role attached to the baseline EC2 instance."
  value       = aws_iam_role.this.name
}

output "iam_role_arn" {
  description = "ARN of the IAM role attached to the baseline EC2 instance."
  value       = aws_iam_role.this.arn
}

output "iam_instance_profile_name" {
  description = "IAM instance profile attached to the baseline EC2 instance."
  value       = aws_iam_instance_profile.this.name
}
