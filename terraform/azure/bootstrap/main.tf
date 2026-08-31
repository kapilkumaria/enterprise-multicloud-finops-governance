resource "random_id" "storage_suffix" {
  byte_length = 3
}

locals {
  resource_group_name = "rg-${var.project_name}-tfstate-cac"

  storage_account_name = substr(
    "stmcfinopstf${random_id.storage_suffix.hex}",
    0,
    24
  )

  common_tags = {
    Project            = "enterprise-multicloud-finops-governance"
    Environment        = "dev"
    Application        = "mc-finops"
    Owner              = "Kapil-Kumaria"
    CostCenter         = "Engineering"
    BusinessUnit       = "Technology"
    ManagedBy          = "Terraform"
    DataClassification = "Internal"
    Purpose            = "TerraformRemoteState"
  }
}

resource "azurerm_resource_group" "terraform_state" {
  name     = local.resource_group_name
  location = var.azure_location

  tags = local.common_tags
}

resource "azurerm_storage_account" "terraform_state" {
  name                     = local.storage_account_name
  resource_group_name      = azurerm_resource_group.terraform_state.name
  location                 = azurerm_resource_group.terraform_state.location
  account_tier             = "Standard"
  account_replication_type = "LRS"

  min_tls_version                   = "TLS1_2"
  https_traffic_only_enabled        = true
  allow_nested_items_to_be_public   = false
  infrastructure_encryption_enabled = true

  blob_properties {
    versioning_enabled = true

    delete_retention_policy {
      days = 7
    }

    container_delete_retention_policy {
      days = 7
    }
  }

  tags = local.common_tags
}

resource "azurerm_storage_container" "terraform_state" {
  name                  = "tfstate"
  storage_account_id    = azurerm_storage_account.terraform_state.id
  container_access_type = "private"
}
