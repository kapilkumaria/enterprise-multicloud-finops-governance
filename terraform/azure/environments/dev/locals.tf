locals {
  project_name = "enterprise-multicloud-finops-governance"
  application  = "mc-finops"

  common_tags = {
    Owner              = "Kapil-Kumaria"
    Environment        = var.environment
    Project            = local.project_name
    Application        = local.application
    CostCenter         = "Engineering"
    BusinessUnit       = "Technology"
    ManagedBy          = "Terraform"
    DataClassification = "Internal"
  }
}
