###############################################################################
# GitHub controlled-remediation role
###############################################################################

resource "aws_iam_role" "github_remediation" {
  provider = aws.github_identity

  name        = "mc-finops-github-aws-remediation"
  path        = "/"
  description = "GitHub Actions OIDC role for controlled mc-finops AWS remediation"

  max_session_duration = 3600

  assume_role_policy = jsonencode({
    Version = "2012-10-17"

    Statement = [
      {
        Sid    = "GitHubActionsMainBranch"
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
    Purpose     = "ControlledRemediation"
  }
}


###############################################################################
# Least-privilege controlled-remediation access
###############################################################################

resource "aws_iam_role_policy" "github_remediation_tag_access" {
  provider = aws.github_identity

  name = "mc-finops-controlled-tag-remediation"
  role = aws_iam_role.github_remediation.id

  policy = jsonencode({
    Version = "2012-10-17"

    Statement = [
      {
        Sid    = "ReadEC2ForVerification"
        Effect = "Allow"

        Action = [
          "ec2:DescribeInstances",
          "ec2:DescribeTags",
        ]

        Resource = "*"
      },

      {
        Sid    = "SetCostCenterOnGovernedDevInstances"
        Effect = "Allow"

        Action = [
          "ec2:CreateTags",
        ]

        Resource = "arn:aws:ec2:us-east-1:${data.aws_caller_identity.current.account_id}:instance/*"

        Condition = {
          StringEquals = {
            "ec2:ResourceTag/Project"     = "enterprise-multicloud-finops-governance"
            "ec2:ResourceTag/Environment" = "dev"
          }

          "ForAllValues:StringEquals" = {
            "aws:TagKeys" = [
              "CostCenter",
            ]
          }
        }
      }
    ]
  })
}
