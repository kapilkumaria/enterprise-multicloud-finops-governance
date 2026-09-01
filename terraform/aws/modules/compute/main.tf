data "aws_ssm_parameter" "amazon_linux_2023" {
  name = "/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64"
}

resource "aws_iam_role" "this" {
  name = "${var.name_prefix}-instance-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"

    Statement = [
      {
        Sid    = "AllowEC2AssumeRole"
        Effect = "Allow"

        Principal = {
          Service = "ec2.amazonaws.com"
        }

        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = merge(
    var.tags,
    {
      Name    = "${var.name_prefix}-instance-role"
      Service = "FinOpsGovernance"
      Purpose = "GovernanceCostBaseline"
    }
  )
}

resource "aws_iam_instance_profile" "this" {
  name = "${var.name_prefix}-instance-profile"
  role = aws_iam_role.this.name

  tags = merge(
    var.tags,
    {
      Name    = "${var.name_prefix}-instance-profile"
      Service = "FinOpsGovernance"
      Purpose = "GovernanceCostBaseline"
    }
  )
}

resource "aws_instance" "this" {
  ami           = data.aws_ssm_parameter.amazon_linux_2023.value
  instance_type = var.instance_type

  subnet_id              = var.subnet_id
  vpc_security_group_ids = [var.security_group_id]

  associate_public_ip_address = false

  monitoring              = true
  ebs_optimized           = true
  disable_api_termination = false

  iam_instance_profile = aws_iam_instance_profile.this.name

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
    instance_metadata_tags      = "disabled"
  }

  root_block_device {
    volume_type           = "gp3"
    volume_size           = var.root_volume_size
    encrypted             = true
    delete_on_termination = true

    tags = merge(
      var.tags,
      {
        Name = "${var.name_prefix}-root-volume"
      }
    )
  }

  tags = merge(
    var.tags,
    {
      Name    = "${var.name_prefix}-baseline-instance"
      Service = "FinOpsGovernance"
      Purpose = "GovernanceCostBaseline"
    }
  )
}
