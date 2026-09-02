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

resource "azurerm_resource_group" "missing_tags" {
  name     = "rg-mc-finops-tag-violation"
  location = "canadacentral"

  tags = {
    Application = "mc-finops"
    Environment = "dev"
    ManagedBy   = "Terraform"
    Project     = "enterprise-multicloud-finops-governance"
  }
}
