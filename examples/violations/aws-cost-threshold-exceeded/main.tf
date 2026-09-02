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

data "aws_ssm_parameter" "amazon_linux_2023" {
  name = "/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64"
}

resource "aws_instance" "cost_violation" {
  ami           = data.aws_ssm_parameter.amazon_linux_2023.value
  instance_type = "m6i.4xlarge"

  monitoring = true

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
  }

  root_block_device {
    encrypted   = true
    volume_type = "gp3"
    volume_size = 20

    tags = local.common_tags
  }

  tags = local.common_tags
}
