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
