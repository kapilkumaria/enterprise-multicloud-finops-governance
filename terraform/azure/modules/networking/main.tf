resource "azurerm_virtual_network" "this" {
  name                = "${var.name_prefix}-vnet"
  location            = var.location
  resource_group_name = var.resource_group_name
  address_space       = var.vnet_address_space

  tags = merge(
    var.tags,
    {
      Name    = "${var.name_prefix}-vnet"
      Service = "FinOpsGovernance"
      Purpose = "GovernanceCostBaseline"
    }
  )
}

resource "azurerm_network_security_group" "compute" {
  name                = "${var.name_prefix}-compute-nsg"
  location            = var.location
  resource_group_name = var.resource_group_name

  tags = merge(
    var.tags,
    {
      Name    = "${var.name_prefix}-compute-nsg"
      Service = "FinOpsGovernance"
      Purpose = "GovernanceCostBaseline"
    }
  )
}

resource "azurerm_subnet" "compute" {
  name                 = "${var.name_prefix}-compute-subnet"
  resource_group_name  = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.this.name
  address_prefixes     = var.subnet_address_prefixes

  default_outbound_access_enabled = false
}

resource "azurerm_subnet_network_security_group_association" "compute" {
  subnet_id                 = azurerm_subnet.compute.id
  network_security_group_id = azurerm_network_security_group.compute.id
}
