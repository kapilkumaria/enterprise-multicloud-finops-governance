terraform {
  backend "s3" {
    bucket       = "mc-finops-aws-tfstate-5e5a89"
    key          = "mc-finops/aws/dev/terraform.tfstate"
    region       = "us-east-1"
    encrypt      = true
    use_lockfile = true
  }
}
