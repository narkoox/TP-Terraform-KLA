terraform {
  required_version = ">= 1.6.0"
  required_providers {
    azurerm = { source = "hashicorp/azurerm", version = "~> 4.10" }
    vault   = { source = "hashicorp/vault",   version = "~> 3.0" }
  }
}

provider "azurerm" {
  features {}
  subscription_id = var.subscription_id
}

provider "vault" {
  address = var.vault_address
}

# Resource Group
resource "azurerm_resource_group" "grp_ressource_test" {
  name     = "grp-ressource-test"
  location = var.location
}

# Réseau: VNet + 2 Subnets
resource "azurerm_virtual_network" "vnet" {
  name                = "test-vnet"
  address_space       = ["10.0.0.0/16"]
  location            = azurerm_resource_group.grp_ressource_test.location
  resource_group_name = azurerm_resource_group.grp_ressource_test.name
}

resource "azurerm_subnet" "subnet_web" {
  name                 = "test-subnet-web"
  resource_group_name  = azurerm_resource_group.grp_ressource_test.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.0.1.0/24"]
}

resource "azurerm_subnet" "subnet_data" {
  name                 = "test-subnet-data"
  resource_group_name  = azurerm_resource_group.grp_ressource_test.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.0.2.0/24"]
}

# NSG (SSH + HTTP) associé au subnet web
resource "azurerm_network_security_group" "grp_sec_net" {
  name                = "vm-sec-net"
  location            = azurerm_resource_group.grp_ressource_test.location
  resource_group_name = azurerm_resource_group.grp_ressource_test.name

  security_rule {
    name                       = "Allow-SSH"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "Allow-HTTP"
    priority                   = 110
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "80"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

resource "azurerm_subnet_network_security_group_association" "subnet_web_nsg" {
  subnet_id                 = azurerm_subnet.subnet_web.id
  network_security_group_id = azurerm_network_security_group.grp_sec_net.id
}

# Public IP pour le Load Balancer
resource "azurerm_public_ip" "ip_public_lb" {
  name                = "mon-ip-public-lb"
  resource_group_name = azurerm_resource_group.grp_ressource_test.name
  location            = azurerm_resource_group.grp_ressource_test.location
  allocation_method   = "Static"
  sku                 = "Standard"
  ip_version          = "IPv4"
}

# Load Balancer Standard + Backend Pool + Probe + Règle 80
resource "azurerm_lb" "test_lb" {
  name                = "test-lb"
  location            = azurerm_resource_group.grp_ressource_test.location
  resource_group_name = azurerm_resource_group.grp_ressource_test.name
  sku                 = "Standard"

  frontend_ip_configuration {
    name                 = "feip"
    public_ip_address_id = azurerm_public_ip.ip_public_lb.id
  }
}

resource "azurerm_lb_backend_address_pool" "test_bepool" {
  name            = "bepool"
  loadbalancer_id = azurerm_lb.test_lb.id
}

resource "azurerm_lb_probe" "http_probe_80" {
  name            = "http-probe-80"
  loadbalancer_id = azurerm_lb.test_lb.id
  protocol        = "Tcp"
  port            = 80
}

resource "azurerm_lb_rule" "http_80" {
  name                           = "http-80"
  loadbalancer_id                = azurerm_lb.test_lb.id
  protocol                       = "Tcp"
  frontend_port                  = 80
  backend_port                   = 80
  frontend_ip_configuration_name = "feip"
  backend_address_pool_ids       = [azurerm_lb_backend_address_pool.test_bepool.id]
  probe_id                       = azurerm_lb_probe.http_probe_80.id
}

# Deux NICs dans le subnet web
resource "azurerm_network_interface" "net_interface_web" {
  for_each            = toset(["web1", "web2"])
  name                = "test-net-interface-${each.key}"
  location            = azurerm_resource_group.grp_ressource_test.location
  resource_group_name = azurerm_resource_group.grp_ressource_test.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.subnet_web.id
    private_ip_address_allocation = "Dynamic"
  }
}

# Associer les NICs au backend pool du LB
resource "azurerm_network_interface_backend_address_pool_association" "nic_bepool_assoc" {
  for_each                = azurerm_network_interface.net_interface_web
  network_interface_id    = each.value.id
  ip_configuration_name   = "internal"
  backend_address_pool_id = azurerm_lb_backend_address_pool.test_bepool.id
}

# 2 VMs Ubuntu 22.04 LTS Gen2 (web1/web2)
locals {
  cloud_init = <<-EOF
    #cloud-config
    package_update: true
    packages:
      - nginx
    runcmd:
      - systemctl enable --now nginx
      - bash -lc 'echo "<h1>$(hostname) - OK</h1>" > /var/www/html/index.html'
  EOF
}

resource "azurerm_linux_virtual_machine" "test_vm_web" {
  for_each                        = azurerm_network_interface.net_interface_web
  name                            = "test-srv-ubuntu-${each.key}"
  resource_group_name             = azurerm_resource_group.grp_ressource_test.name
  location                        = azurerm_resource_group.grp_ressource_test.location
  size                            = "Standard_B1s"
  admin_username                  = "azureuser"
  disable_password_authentication = true

  network_interface_ids = [each.value.id]

  admin_ssh_key {
    username   = "azureuser"
    public_key = data.vault_kv_secret_v2.ssh_key.data["value"]
  }

  os_disk {
    name                 = "test-srv-ubuntu-${each.key}-osdisk"
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
    disk_size_gb         = 30
  }

  # Ubuntu 22.04 LTS (Jammy) Gen2
  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts-gen2"
    version   = "latest"
  }

  computer_name = "test-srv-ubuntu-${each.key}"
  custom_data   = base64encode(local.cloud_init)
  tags          = { role = "web", env = "demo" }
}

# Outputs
output "lb_public_ip" {
  value       = azurerm_public_ip.ip_public_lb.ip_address
  description = "IP publique du Load Balancer"
}
