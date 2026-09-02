terraform {
  required_version = ">= 1.7.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}

provider "aws" {
  region = "us-east-1"
}

resource "aws_s3_bucket" "missing_tags" {
  bucket_prefix = "mc-finops-tag-violation-"

  tags = {
    Application = "mc-finops"
    Environment = "dev"
    ManagedBy   = "Terraform"
    Project     = "enterprise-multicloud-finops-governance"
  }
}
