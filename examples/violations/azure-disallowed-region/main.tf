terraform {
  required_version = ">= 1.7.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
  }
}

provider "azurerm" {
  features {}
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

resource "azurerm_resource_group" "region_violation" {
  name     = "rg-mc-finops-region-violation"
  location = "eastus"

  tags = local.common_tags
}
