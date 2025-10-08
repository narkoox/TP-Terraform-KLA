resource "local_file" "inventory_ini" {
  filename = "${path.module}/ansible/inventory.ini"
  content  = templatefile("${path.module}/templates/inventory.ini.tmpl", {
    master_pub_ip   = azurerm_public_ip.pip_master.ip_address
    admin_user      = var.admin_user
    worker_priv_ips = [for n in azurerm_network_interface.worker : n.ip_configuration[0].private_ip_address]
  })
}

resource "null_resource" "ansible_apply" {
  depends_on = [
    azurerm_linux_virtual_machine.master,
    azurerm_linux_virtual_machine.worker,
    local_file.inventory_ini
  ]

  triggers = {
    inv_sha  = sha1(local_file.inventory_ini.content)
    pod_cidr = var.pod_cidr
  }

  provisioner "local-exec" {
    working_dir = "${path.module}/ansible"
    command     = "ANSIBLE_HOST_KEY_CHECKING=False ansible-playbook -i inventory.ini site.yml --extra-vars pod_cidr=${var.pod_cidr}"
  }
}
