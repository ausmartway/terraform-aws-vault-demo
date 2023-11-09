locals {
  user_data = templatefile("${path.module}/templates/userdata.yaml", {
    ip_address    = var.private_ip,
    vault_license = var.vault_license
    vault_conf = base64encode(templatefile("${path.module}/templates/vault.conf",
      {
        listener     = var.private_ip
        ip_addresses = [var.private_ip]
        node_id      = var.hostname
        leader_ip    = var.private_ip
        kms_key_id   = aws_kms_key.aws_kms_key.id
      }
    ))
    slack_webhook = var.slack_webhook
  })
}