terraform {
  backend "azurerm" {
    resource_group_name  = "rg-mc-finops-tfstate-cac"
    storage_account_name = "stmcfinopstf897bcb"
    container_name       = "tfstate"
    key                  = "mc-finops/azure/dev/terraform.tfstate"

    use_azuread_auth = true
  }
}
