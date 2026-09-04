###############################################################################
# Azure controlled-remediation RBAC
###############################################################################

data "azurerm_subscription" "current" {}

locals {
  azure_remediation_vm_id = "/subscriptions/${data.azurerm_subscription.current.subscription_id}/resourceGroups/rg-mc-finops-dev-cac/providers/Microsoft.Compute/virtualMachines/mc-finops-dev-baseline-vm"
}

resource "azurerm_role_assignment" "github_remediation_reader" {
  scope                = local.azure_remediation_vm_id
  role_definition_name = "Reader"
  principal_id         = azuread_service_principal.github_remediation.object_id

  principal_type = "ServicePrincipal"
}

resource "azurerm_role_assignment" "github_remediation_tag_contributor" {
  scope                = local.azure_remediation_vm_id
  role_definition_name = "Tag Contributor"
  principal_id         = azuread_service_principal.github_remediation.object_id

  principal_type = "ServicePrincipal"
}
