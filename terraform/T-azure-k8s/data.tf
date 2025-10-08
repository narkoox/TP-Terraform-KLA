# Vault: on réutilise ta logique et ton champ "value"
data "vault_kv_secret_v2" "ssh_key" {
  mount = "ssh"
  name  = "public_key"
}

