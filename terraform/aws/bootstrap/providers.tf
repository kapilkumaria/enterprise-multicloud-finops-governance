terraform {
  required_version = ">= 1.15.0, < 1.16.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
    }
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project            = "enterprise-multicloud-finops-governance"
      Environment        = "dev"
      Application        = "mc-finops"
      Owner              = "Kapil-Kumaria"
      CostCenter         = "Engineering"
      BusinessUnit       = "Technology"
      ManagedBy          = "Terraform"
      DataClassification = "Internal"
    }
  }
}

###############################################################################
# Adopted GitHub identity resources
#
# These IAM resources pre-date the bootstrap provider's expanded default-tag
# policy. Keep their existing metadata stable during Terraform adoption.
###############################################################################

provider "aws" {
  alias  = "github_identity"
  region = var.aws_region
}
