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

output "github_actions_oidc_provider_arn" {
  description = "AWS IAM OIDC provider used by GitHub Actions."
  value       = aws_iam_openid_connect_provider.github_actions.arn
}

output "github_deploy_role_name" {
  description = "AWS IAM role assumed by GitHub Actions for controlled deployment and planning."
  value       = aws_iam_role.github_deploy.name
}

output "github_deploy_role_arn" {
  description = "AWS IAM role ARN assumed by GitHub Actions."
  value       = aws_iam_role.github_deploy.arn
}
