resource "azurerm_resource_group" "rg" {
  name     = var.resource_group_name
  location = var.location
}

resource "azurerm_virtual_network" "vnet" {
  name                = "MTC-Vnet"
  location            = var.location
  resource_group_name = azurerm_resource_group.rg.name
  address_space       = ["10.0.0.0/16"]
}

resource "azurerm_subnet" "app_subnet" {
  name                 = "app-subnet"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.0.1.0/24"]
}

resource "azurerm_subnet" "db_subnet" {
  name                 = "db-subnet"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.0.2.0/24"]
}

resource "azurerm_public_ip" "app_pip" {
  name                = "app-pip"
  location            = var.location
  resource_group_name = azurerm_resource_group.rg.name
  allocation_method   = "Static"
}

resource "azurerm_network_interface" "app_nic" {
  name                = "app-nic"
  location            = var.location
  resource_group_name = azurerm_resource_group.rg.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.app_subnet.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.app_pip.id
  }
}

resource "azurerm_network_interface" "db_nic" {
  name                = "db-nic"
  location            = var.location
  resource_group_name = azurerm_resource_group.rg.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.db_subnet.id
    private_ip_address_allocation = "Dynamic"
  }
}

module "app_server" {
  source = "git::https://github.com/6267136444/terraform-azure-modules.git//modules/virtual-machine?ref=v2.0.0"

  vm_name             = "app-server"
  location            = var.location
  resource_group_name = azurerm_resource_group.rg.name
  vm_size             = "Standard_D8as_v5"

  os_type = "windows"

  admin_username = var.admin_username
  admin_password = var.admin_password

  nic_id = azurerm_network_interface.app_nic.id

  data_disk_size_gb = 4096
}

module "db_server" {
  source = "git::https://github.com/6267136444/terraform-azure-modules.git//modules/virtual-machine?ref=v2.0.0"

  vm_name             = "db-server"
  location            = var.location
  resource_group_name = azurerm_resource_group.rg.name
  vm_size             = "Standard_D8as_v5"

  os_type = "linux"

  admin_username = var.admin_username
  admin_password = var.admin_password

  nic_id = azurerm_network_interface.db_nic.id

  data_disk_size_gb = 6144

  custom_data = filebase64("mysql-install.sh")
}
