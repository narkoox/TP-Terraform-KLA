data "azurerm_platform_image" "ubuntu" {
  location  = var.location
  publisher = "Canonical"
  offer     = "0001-com-ubuntu-server-jammy"
  sku       = "22_04-lts-gen2"
  version   = "latest"
}

locals {
  cloud_init_min = <<-EOF
    #cloud-config
    package_update: true
    runcmd:
      - apt-get update
      - apt-get install -y python3 python3-apt
      - swapoff -a
      - sed -i.bak '/ swap / s/^/#/' /etc/fstab
      - modprobe overlay
      - modprobe br_netfilter
      - printf "overlay\nbr_netfilter\n" > /etc/modules-load.d/k8s.conf
      - printf "net.bridge.bridge-nf-call-iptables=1\nnet.bridge.bridge-nf-call-ip6tables=1\nnet.ipv4.ip_forward=1\n" > /etc/sysctl.d/99-kubernetes-cri.conf
      - sysctl --system
  EOF
}

resource "azurerm_linux_virtual_machine" "master" {
  name                = "k8s-master"
  location            = var.location
  resource_group_name = azurerm_resource_group.rg.name
  size                = var.vm_size_master
  network_interface_ids = [azurerm_network_interface.master.id]

  admin_username                  = var.admin_user
  disable_password_authentication = true

  admin_ssh_key {
    username   = var.admin_user
    public_key = data.vault_kv_secret_v2.ssh_key.data["pubkey"]
  }

  source_image_reference {
    publisher = data.azurerm_platform_image.ubuntu.publisher
    offer     = data.azurerm_platform_image.ubuntu.offer
    sku       = data.azurerm_platform_image.ubuntu.sku
    version   = data.azurerm_platform_image.ubuntu.version
  }

  os_disk {
    name                 = "osdisk-master"
    caching              = "ReadWrite"
    storage_account_type = "StandardSSD_LRS"
    disk_size_gb         = 40
  }

  custom_data = base64encode(local.cloud_init_min)
}

resource "azurerm_linux_virtual_machine" "worker" {
  count               = var.workers_count
  name                = "k8s-worker-${count.index+1}"
  location            = var.location
  resource_group_name = azurerm_resource_group.rg.name
  size                = var.vm_size_worker
  network_interface_ids = [azurerm_network_interface.worker[count.index].id]

  admin_username                  = var.admin_user
  disable_password_authentication = true

  admin_ssh_key {
    username   = var.admin_user
    public_key = data.vault_kv_secret_v2.ssh_key.data["pubkey"]
  }

  source_image_reference {
    publisher = data.azurerm_platform_image.ubuntu.publisher
    offer     = data.azurerm_platform_image.ubuntu.offer
    sku       = data.azurerm_platform_image.ubuntu.sku
    version   = data.azurerm_platform_image.ubuntu.version
  }

  os_disk {
    name                 = "osdisk-worker-${count.index+1}"
    caching              = "ReadWrite"
    storage_account_type = "StandardSSD_LRS"
    disk_size_gb         = 40
  }

  custom_data = base64encode(local.cloud_init_min)
}
