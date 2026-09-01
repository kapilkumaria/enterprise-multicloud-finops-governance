# AWS dev environment orchestration will be added incrementally.
#
# Provider-specific modules such as storage, compute, budget and governance
# will be called from this root module as they are implemented.

module "networking" {
  source = "../../modules/networking"

  name_prefix        = "${local.application}-${var.environment}"
  vpc_cidr           = "10.70.0.0/16"
  public_subnet_cidr = "10.70.10.0/24"
  availability_zone  = "${var.aws_region}a"

  tags = local.common_tags
}

module "compute" {
  source = "../../modules/compute"

  name_prefix       = "${local.application}-${var.environment}"
  subnet_id         = module.networking.public_subnet_id
  security_group_id = module.networking.security_group_id

  instance_type    = var.aws_instance_type
  root_volume_size = var.aws_root_volume_size

  tags = local.common_tags
}
