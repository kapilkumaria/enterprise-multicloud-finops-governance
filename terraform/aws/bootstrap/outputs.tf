output "terraform_state_bucket_name" {
  description = "S3 bucket used for AWS Terraform remote state."
  value       = aws_s3_bucket.terraform_state.bucket
}

output "terraform_state_bucket_region" {
  description = "Region containing the AWS Terraform state bucket."
  value       = var.aws_region
}

output "terraform_state_key" {
  description = "Recommended state key for the AWS dev environment."
  value       = "mc-finops/aws/dev/terraform.tfstate"
}

output "terraform_state_locking" {
  description = "Terraform S3 backend locking configuration."
  value       = "use_lockfile = true"
}
