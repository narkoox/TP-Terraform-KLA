resource "azurerm_resource_group" "rg" {
  name     = var.rg_name
  location = var.location
}

resource "azurerm_virtual_network" "vnet" {
  name                = "vnet-k8s"
  location            = var.location
  resource_group_name = azurerm_resource_group.rg.name
  address_space       = [var.vnet_cidr]
}

resource "azurerm_subnet" "subnet" {
  name                 = "snet-k8s"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = [var.subnet_cidr]
}

resource "azurerm_network_security_group" "nsg" {
  name                = "nsg-k8s"
  location            = var.location
  resource_group_name = azurerm_resource_group.rg.name

  security_rule {
    name = "ssh"
    priority = 100
    direction = "Inbound"
    access = "Allow"
    protocol = "Tcp"
    source_port_range = "*"
    destination_port_range = "22"
    source_address_prefix = var.ssh_allowed_cidr
    destination_address_prefix = "*"
  }

  security_rule {
    name = "apiserver-internal-6443"
    priority = 110
    direction = "Inbound"
    access = "Allow"
    protocol = "Tcp"
    source_port_range = "*"
    destination_port_range = "6443"
    source_address_prefix = azurerm_subnet.subnet.address_prefixes[0]
    destination_address_prefix = "*"
  }

  security_rule {
    name = "kube-internal"
    priority = 120
    direction = "Inbound"
    access = "Allow"
    protocol = "Tcp"
    source_port_range = "*"
    destination_port_ranges = ["10250","10257","10259","2379","2380","30000-32767"]
    source_address_prefix = azurerm_subnet.subnet.address_prefixes[0]
    destination_address_prefix = "*"
  }

  security_rule {
    name = "calico-bgp-179"
    priority = 130
    direction = "Inbound"
    access = "Allow"
    protocol = "Tcp"
    source_port_range = "*"
    destination_port_range = "179"
    source_address_prefix = azurerm_subnet.subnet.address_prefixes[0]
    destination_address_prefix = "*"
  }
}

resource "azurerm_public_ip" "pip_master" {
  name                = "pip-k8s-master"
  location            = var.location
  resource_group_name = azurerm_resource_group.rg.name
  allocation_method   = "Static"
  sku                 = "Standard"
}

resource "azurerm_network_interface" "master" {
  name                = "nic-k8s-master"
  location            = var.location
  resource_group_name = azurerm_resource_group.rg.name

  ip_configuration {
    name                          = "ipconfig1"
    subnet_id                     = azurerm_subnet.subnet.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.pip_master.id
  }
}

resource "azurerm_network_interface_security_group_association" "nsg_master" {
  network_interface_id      = azurerm_network_interface.master.id
  network_security_group_id = azurerm_network_security_group.nsg.id
}

resource "azurerm_network_interface" "worker" {
  count               = var.workers_count
  name                = "nic-k8s-worker-${count.index+1}"
  location            = var.location
  resource_group_name = azurerm_resource_group.rg.name

  ip_configuration {
    name                          = "ipconfig1"
    subnet_id                     = azurerm_subnet.subnet.id
    private_ip_address_allocation = "Dynamic"
  }
}

resource "azurerm_network_interface_security_group_association" "nsg_worker" {
  count                      = var.workers_count
  network_interface_id      = azurerm_network_interface.worker[count.index].id
  network_security_group_id = azurerm_network_security_group.nsg.id
}
