resource "azurerm_resource_group" "dev" {
  name     = "rg-mc-finops-dev-cac"
  location = var.azure_location

  tags = local.common_tags
}

module "networking" {
  source = "../../modules/networking"

  name_prefix         = "${local.application}-${var.environment}"
  resource_group_name = azurerm_resource_group.dev.name
  location            = azurerm_resource_group.dev.location

  vnet_address_space      = var.vnet_address_space
  subnet_address_prefixes = var.subnet_address_prefixes

  tags = local.common_tags
}

module "compute" {
  source = "../../modules/compute"

  name_prefix         = "mc-finops-${var.environment}"
  location            = azurerm_resource_group.dev.location
  resource_group_name = azurerm_resource_group.dev.name

  subnet_id = module.networking.subnet_id

  vm_size        = var.azure_vm_size
  admin_username = var.azure_admin_username
  ssh_public_key = var.azure_ssh_public_key

  tags = local.common_tags
}

module "budget" {
  source = "../../modules/budget"

  name              = "mc-finops-dev-monthly-budget"
  resource_group_id = azurerm_resource_group.dev.id
  monthly_limit     = var.azure_monthly_budget
  start_date        = var.azure_budget_start_date

  notification_threshold_percent = (
    var.azure_budget_notification_threshold_percent
  )

  notification_contact_emails = (
    var.azure_budget_notification_emails
  )
}
