terraform {
  required_version = ">= 1.5.0"
  required_providers {
    azurerm = { source = "hashicorp/azurerm", version = "~> 4.2" }
    random  = { source = "hashicorp/random",  version = "~> 3.6" }
    local   = { source = "hashicorp/local",   version = "~> 2.5" }
    vault   = { source = "hashicorp/vault",   version = "~> 4.3" }
  }
}

provider "azurerm" {
  features {}
  subscription_id = var.subscription_id
}

provider "vault" {
  address = var.vault_address   # ex: http://10.10.10.50:8200
  # le token vient de $VAULT_TOKEN (recommandé)
}
