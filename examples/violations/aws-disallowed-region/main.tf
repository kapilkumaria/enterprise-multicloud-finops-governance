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
  region = "us-west-2"
}

locals {
  common_tags = {
    Application        = "mc-finops"
    BusinessUnit       = "Technology"
    CostCenter         = "Engineering"
    DataClassification = "Internal"
    Environment        = "dev"
    ManagedBy          = "Terraform"
    Owner              = "Kapil-Kumaria"
    Project            = "enterprise-multicloud-finops-governance"
  }
}

resource "aws_s3_bucket" "region_violation" {
  bucket_prefix = "mc-finops-region-violation-"

  tags = local.common_tags
}
