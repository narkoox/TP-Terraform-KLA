data "vault_kv_secret_v2" "ssh_key" {
  mount = "ssh"
  name  = "public_key"
}
