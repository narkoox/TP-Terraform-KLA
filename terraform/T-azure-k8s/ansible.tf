# ansible.tf
#
# Génère ansible.cfg + inventory.ini, attend le SSH du master (avec la bonne clé),
# puis lance Ansible automatiquement.

# 1) ansible.cfg (désactive host_key_checking, active pipelining)
resource "local_file" "ansible_cfg" {
  filename = "${path.module}/ansible/ansible.cfg"
  content  = <<-EOT
    [defaults]
    host_key_checking = False
    pipelining = True
    forks = 10
    timeout = 30

    [ssh_connection]
    ssh_args = -o ControlMaster=auto -o ControlPersist=60s -o ServerAliveInterval=30
  EOT
}

# 2) inventory.ini (workers via jump host = master) + IP privée du master pour l'API
resource "local_file" "inventory_ini" {
  filename = "${path.module}/ansible/inventory.ini"
  content  = templatefile("${path.module}/templates/inventory.ini.tmpl", {
    master_pub_ip        = azurerm_public_ip.pip_master.ip_address
    master_priv_ip       = azurerm_network_interface.master.ip_configuration[0].private_ip_address
    admin_user           = var.admin_user
    worker_priv_ips      = [for n in azurerm_network_interface.worker : n.ip_configuration[0].private_ip_address]
    ssh_private_key_file = var.ssh_private_key_file
  })
}

# 3) Attente SSH master (boucle avec retries) — ${i} échappé → $${i} et usage de -i <clé>
resource "null_resource" "wait_ssh_master" {
  depends_on = [
    azurerm_linux_virtual_machine.master,
    azurerm_linux_virtual_machine.worker,
    local_file.inventory_ini,
    local_file.ansible_cfg
  ]

  triggers = {
    master_ip = azurerm_public_ip.pip_master.ip_address
    user      = var.admin_user
    key       = var.ssh_private_key_file
  }

  provisioner "local-exec" {
    command = <<-EOC
      set -e
      echo ">> Waiting SSH on ${var.admin_user}@${azurerm_public_ip.pip_master.ip_address} ..."
      for i in $(seq 1 60); do
        ssh -i "${var.ssh_private_key_file}" -o StrictHostKeyChecking=no -o BatchMode=yes -o ConnectTimeout=5 "${var.admin_user}@${azurerm_public_ip.pip_master.ip_address}" "echo ok" >/dev/null 2>&1 && exit 0
        echo "   SSH not ready yet ($${i}/60), retrying in 10s..."
        sleep 10
      done
      echo "!! SSH still not reachable after 10 minutes."
      exit 1
    EOC
  }
}

# 4) Lancement auto d'Ansible (se relance si fichiers changent)
resource "null_resource" "ansible_apply" {
  depends_on = [
    null_resource.wait_ssh_master
  ]

  # Rebuild si inventaire/cfg/playbook/roles ou pod_cidr changent
  triggers = {
    inv_sha         = sha1(local_file.inventory_ini.content)
    cfg_sha         = sha1(local_file.ansible_cfg.content)
    site_sha        = filesha1("${path.module}/ansible/site.yml")
    common_tasks    = filesha1("${path.module}/ansible/roles/common/tasks/main.yml")
    common_handlers = filesha1("${path.module}/ansible/roles/common/handlers/main.yml")
    master_tasks    = filesha1("${path.module}/ansible/roles/master/tasks/main.yml")
    worker_tasks    = filesha1("${path.module}/ansible/roles/worker/tasks/main.yml")
    pod_cidr        = var.pod_cidr
  }

  provisioner "local-exec" {
    working_dir = "${path.module}/ansible"
    command     = "ansible-playbook -i inventory.ini site.yml --extra-vars pod_cidr=${var.pod_cidr}"
    environment = {
      ANSIBLE_CONFIG = "${path.module}/ansible/ansible.cfg"
    }
  }
}

