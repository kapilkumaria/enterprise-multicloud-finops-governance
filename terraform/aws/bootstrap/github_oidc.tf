###############################################################################
# GitHub Actions OIDC provider
###############################################################################

resource "aws_iam_openid_connect_provider" "github_actions" {
  provider = aws.github_identity

  url = "https://token.actions.githubusercontent.com"

  client_id_list = [
    "sts.amazonaws.com",
  ]

  thumbprint_list = [
    "ab9d0263244dd0326eb67015705a667e79cfe998",
  ]

  tags = {
    Project     = "enterprise-multicloud-finops-governance"
    Environment = "dev"
    Application = "mc-finops"
    Owner       = "Kapil-Kumaria"
    ManagedBy   = "TerraformBootstrap"
  }
}


###############################################################################
# GitHub deployment role
###############################################################################

resource "aws_iam_role" "github_deploy" {
  provider = aws.github_identity

  description = "GitHub Actions OIDC deployment role for mc-finops AWS dev infrastructure"

  name                 = "mc-finops-github-aws-deploy"
  path                 = "/"
  max_session_duration = 3600

  assume_role_policy = jsonencode({
    Version = "2012-10-17"

    Statement = [
      {
        Effect = "Allow"

        Principal = {
          Federated = aws_iam_openid_connect_provider.github_actions.arn
        }

        Action = "sts:AssumeRoleWithWebIdentity"

        Condition = {
          StringEquals = {
            "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"

            "token.actions.githubusercontent.com:sub" = "repo:kapilkumaria@42500918/enterprise-multicloud-finops-governance@1352786623:ref:refs/heads/main"
          }
        }
      }
    ]
  })

  tags = {
    Project     = "enterprise-multicloud-finops-governance"
    Environment = "dev"
    Application = "mc-finops"
    Owner       = "Kapil-Kumaria"
    ManagedBy   = "TerraformBootstrap"
  }
}


###############################################################################
# Terraform backend access
###############################################################################

resource "aws_iam_role_policy" "github_deploy_backend_access" {
  provider = aws.github_identity

  name = "mc-finops-terraform-backend-access"
  role = aws_iam_role.github_deploy.id

  policy = jsonencode({
    Version = "2012-10-17"

    Statement = [
      {
        Sid    = "ListTerraformStatePath"
        Effect = "Allow"

        Action = [
          "s3:ListBucket",
        ]

        Resource = "arn:aws:s3:::mc-finops-aws-tfstate-5e5a89"

        Condition = {
          StringLike = {
            "s3:prefix" = [
              "mc-finops/aws/dev/*",
            ]
          }
        }
      },
      {
        Sid    = "ReadWriteTerraformState"
        Effect = "Allow"

        Action = [
          "s3:GetObject",
          "s3:PutObject",
        ]

        Resource = "arn:aws:s3:::mc-finops-aws-tfstate-5e5a89/mc-finops/aws/dev/terraform.tfstate"
      },
      {
        Sid    = "ManageTerraformStateLock"
        Effect = "Allow"

        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject",
        ]

        Resource = "arn:aws:s3:::mc-finops-aws-tfstate-5e5a89/mc-finops/aws/dev/terraform.tfstate.tflock"
      },
    ]
  })
}


###############################################################################
# Resolved-cost read access
###############################################################################

resource "aws_iam_role_policy" "github_deploy_resolved_cost_read" {
  provider = aws.github_identity

  name = "mc-finops-resolved-cost-read-access"
  role = aws_iam_role.github_deploy.id

  policy = jsonencode({
    Version = "2012-10-17"

    Statement = [
      {
        Sid    = "ReadAmazonLinux2023PublicAMIParameter"
        Effect = "Allow"

        Action = [
          "ssm:GetParameter",
        ]

        Resource = "arn:aws:ssm:us-east-1::parameter/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64"
      },
    ]
  })
}
