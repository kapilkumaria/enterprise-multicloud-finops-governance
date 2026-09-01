resource "azurerm_network_interface" "this" {
  name                = "${var.name_prefix}-nic"
  location            = var.location
  resource_group_name = var.resource_group_name

  ip_configuration {
    name                          = "primary"
    subnet_id                     = var.subnet_id
    private_ip_address_allocation = "Dynamic"
  }

  tags = merge(
    var.tags,
    {
      Name    = "${var.name_prefix}-nic"
      Service = "FinOpsGovernance"
      Purpose = "GovernanceCostBaseline"
    }
  )
}

resource "azurerm_linux_virtual_machine" "this" {
  name                = "${var.name_prefix}-baseline-vm"
  location            = var.location
  resource_group_name = var.resource_group_name

  size           = var.vm_size
  admin_username = var.admin_username

  network_interface_ids = [
    azurerm_network_interface.this.id
  ]

  disable_password_authentication = true
  allow_extension_operations      = false

  secure_boot_enabled = true
  vtpm_enabled        = true

  encryption_at_host_enabled = true

  admin_ssh_key {
    username   = var.admin_username
    public_key = var.ssh_public_key
  }

  os_disk {
    name                 = "${var.name_prefix}-osdisk"
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
    disk_size_gb         = 30
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "ubuntu-24_04-lts"
    sku       = "server"
    version   = "latest"
  }

  identity {
    type = "SystemAssigned"
  }

  boot_diagnostics {}

  tags = merge(
    var.tags,
    {
      Name    = "${var.name_prefix}-baseline-vm"
      Service = "FinOpsGovernance"
      Purpose = "GovernanceCostBaseline"
    }
  )
}
