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

resource "azurerm_resource_group" "cost_violation" {
  name     = "rg-mc-finops-cost-violation"
  location = "canadacentral"

  tags = local.common_tags
}

resource "azurerm_virtual_network" "cost_violation" {
  name                = "vnet-mc-finops-cost-violation"
  location            = azurerm_resource_group.cost_violation.location
  resource_group_name = azurerm_resource_group.cost_violation.name
  address_space       = ["10.90.0.0/16"]

  tags = local.common_tags
}

resource "azurerm_subnet" "cost_violation" {
  name                 = "snet-mc-finops-cost-violation"
  resource_group_name  = azurerm_resource_group.cost_violation.name
  virtual_network_name = azurerm_virtual_network.cost_violation.name
  address_prefixes     = ["10.90.10.0/24"]
}

resource "azurerm_network_interface" "cost_violation" {
  name                = "nic-mc-finops-cost-violation"
  location            = azurerm_resource_group.cost_violation.location
  resource_group_name = azurerm_resource_group.cost_violation.name

  ip_configuration {
    name                          = "primary"
    subnet_id                     = azurerm_subnet.cost_violation.id
    private_ip_address_allocation = "Dynamic"
  }

  tags = local.common_tags
}

resource "azurerm_linux_virtual_machine" "cost_violation" {
  name                = "vm-mc-finops-cost-violation"
  location            = azurerm_resource_group.cost_violation.location
  resource_group_name = azurerm_resource_group.cost_violation.name

  size = "Standard_D16s_v5"

  admin_username                  = "azureadmin"
  disable_password_authentication = true

  network_interface_ids = [
    azurerm_network_interface.cost_violation.id
  ]

  admin_ssh_key {
    username   = "azureadmin"
    public_key = file("~/.ssh/id_ed25519.pub")
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "ubuntu-24_04-lts"
    sku       = "server"
    version   = "latest"
  }

  tags = local.common_tags
}
