variable "subscription_id" {
  type        = string
  description = "1c450166-d3fb-4c9e-b800-503c3d629916"
}

variable "location" {
  type        = string
  description = "Région Azure (ex: francecentral, westeurope)"
  default     = "francecentral"
}

variable "vault_address" {
  type        = string
  default     = "http://10.10.10.50:8200"
  description = "Adresse de Vault"
}

# Infra
variable "rg_name"       { default = "rg-k8s-kubeadm" }
variable "vnet_cidr"     { default = "10.42.0.0/16" }
variable "subnet_cidr"   { default = "10.42.1.0/24" }

# Accès
variable "admin_user"      { default = "azureuser" }
variable "ssh_allowed_cidr"{
  description = "Ton /32 public pour SSH sur le master (ou * pour tests)"
  default     = "*"
}

# K8s
variable "pod_cidr"        { default = "192.168.0.0/16" }
variable "workers_count"   { default = 2 }

# VM sizes
variable "vm_size_master"  { default = "Standard_B2s" }
variable "vm_size_worker"  { default = "Standard_B2s" }