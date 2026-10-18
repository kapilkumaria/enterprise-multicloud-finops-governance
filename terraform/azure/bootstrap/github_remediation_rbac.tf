###############################################################################
# Azure controlled-remediation RBAC
###############################################################################

data "azurerm_subscription" "current" {}

locals {
  azure_remediation_vm_id = "/subscriptions/${data.azurerm_subscription.current.subscription_id}/resourceGroups/rg-mc-finops-dev-cac/providers/Microsoft.Compute/virtualMachines/mc-finops-dev-baseline-vm"
}

resource "azurerm_role_assignment" "github_remediation_reader" {
  count                = var.enable_vm_remediation_rbac ? 1 : 0
  scope                = local.azure_remediation_vm_id
  role_definition_name = "Reader"
  principal_id         = azuread_service_principal.github_remediation.object_id

  principal_type = "ServicePrincipal"
}

resource "azurerm_role_assignment" "github_remediation_tag_contributor" {
  count                = var.enable_vm_remediation_rbac ? 1 : 0
  scope                = local.azure_remediation_vm_id
  role_definition_name = "Tag Contributor"
  principal_id         = azuread_service_principal.github_remediation.object_id

  principal_type = "ServicePrincipal"
}


###############################################################################
# Preserve Terraform resource address history after introducing count.
###############################################################################

moved {
  from = azurerm_role_assignment.github_remediation_reader
  to   = azurerm_role_assignment.github_remediation_reader[0]
}

moved {
  from = azurerm_role_assignment.github_remediation_tag_contributor
  to   = azurerm_role_assignment.github_remediation_tag_contributor[0]
}
