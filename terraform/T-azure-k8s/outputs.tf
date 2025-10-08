output "master_public_ip"  { value = azurerm_public_ip.pip_master.ip_address }
output "master_private_ip" { value = azurerm_network_interface.master.ip_configuration[0].private_ip_address }

output "workers_private_ips" {
  value = [for n in azurerm_network_interface.worker : n.ip_configuration[0].private_ip_address]
}
