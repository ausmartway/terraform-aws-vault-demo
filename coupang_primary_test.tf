locals {
  user_data_coupang_primary = templatefile("${path.module}/templates/userdata.yaml", {
    ip_address    = "10.0.101.163",
    vault_license = var.vault_license
    vault_conf = base64encode(templatefile("${path.module}/templates/vault.conf",
      {
        listener     = "10.0.101.163"
        ip_addresses = ["10.0.101.163"]
        node_id      = var.hostname
        leader_ip    = "10.0.101.163"
        kms_key_id   = local.kms_key_id
      }
    ))
    slack_webhook = var.slack_webhook
  })
}

variable "customer-poc-tags" {
  type = map(any)
  default = {
    Name        = "coupang-primary-vault"
    TTL         = "192"
    owner       = "yulei@hashicorp.com"
    Region      = "APJ"
    description = "General vault demo instance"
  }
}

resource "aws_lb" "coupang-primary-vault" {
  name               = "coupang-primary-vault-nlb"
  internal           = false
  load_balancer_type = "network"
  subnets            = [local.public_subnets[0]]

  enable_deletion_protection = false

  tags = var.customer-poc-tags
  security_groups = [
    local.security_group_outbound,
    local.security_group_ssh,
  module.security_group_vault.security_group_id, ]
}

resource "aws_lb_target_group" "coupang-primary-vault" {
  name     = "coupang-primary-vault"
  port     = 8200
  protocol = "TCP"

  health_check {
    path     = "/v1/sys/health?standbycode=200&sealedcode=200&uninitcode=200"
    port     = "8200"
    protocol = "HTTP"
    timeout  = 2
    interval = 5
  }

  vpc_id     = local.vpc_id
  depends_on = [aws_lb.coupang-primary-vault]
}

resource "aws_lb_target_group" "coupang-primary-vault-8201" {
  name     = "coupang-primary-vault-8201"
  port     = 8201
  protocol = "TCP"

  health_check {
    path     = "/v1/sys/health?standbycode=200&sealedcode=200&uninitcode=200"
    port     = "8200"
    protocol = "HTTP"
    timeout  = 2
    interval = 5
  }

  vpc_id     = local.vpc_id
  depends_on = [aws_lb.coupang-primary-vault]
}



resource "aws_lb_listener" "coupang-primary-vault" {
  load_balancer_arn = aws_lb.coupang-primary-vault.arn
  port              = "8200"
  protocol          = "TCP"

  default_action {
    target_group_arn = aws_lb_target_group.coupang-primary-vault.arn
    type             = "forward"
  }
}

resource "aws_lb_listener" "coupang-primary-vault-8201" {
  load_balancer_arn = aws_lb.coupang-primary-vault.arn
  port              = "8201"
  protocol          = "TCP"

  default_action {
    target_group_arn = aws_lb_target_group.coupang-primary-vault-8201.arn
    type             = "forward"
  }
}

resource "aws_lb_target_group_attachment" "coupang-primary-vault" {
  target_group_arn = aws_lb_target_group.coupang-primary-vault.arn
  target_id        = module.coupang-primary-vault.id
  port             = 8200
}

resource "aws_lb_target_group_attachment" "coupang-primary-vault-8201" {
  target_group_arn = aws_lb_target_group.coupang-primary-vault-8201.arn
  target_id        = module.coupang-primary-vault.id
  port             = 8201
}



module "coupang-primary-vault" {
  source  = "terraform-aws-modules/ec2-instance/aws"
  version = "5.3.1"

  name = "coupang-primary-vault"

  private_ip = "10.0.101.163"

  user_data_base64 = base64gzip(local.user_data_coupang_primary)

  ami                         = data.aws_ami.ubuntu.id
  instance_type               = var.instance_type
  key_name                    = var.key_name
  iam_instance_profile        = aws_iam_instance_profile.coupang-primary-vault.name
  associate_public_ip_address = false

  monitoring = true
  vpc_security_group_ids = [
    local.security_group_outbound,
    local.security_group_ssh,
    module.security_group_vault_from_public_subnets_to_private_subnets.security_group_id
  ]

  subnet_id = local.public_subnets[0]
  tags      = var.customer-poc-tags
}

# resource "aws_route53_record" "coupang-primary-vault" {
#   zone_id = data.aws_route53_zone.this.id
#   name    = "coupang-primary-vault.${data.aws_route53_zone.this.name}"
#   type    = "A"
#   ttl     = "300"
#   records = [module.coupang-primary-vault.public_ip]
# }

output "coupang-primary-vaultc_cluster_url" {
  value = aws_lb.coupang-primary-vault.dns_name
}

# output "coupang-primary-vaultc_cluster_url-direct" {
#   value = aws_route53_record.coupang-primary-vault.name
# }

resource "aws_iam_instance_profile" "coupang-primary-vault" {
  name_prefix = var.hostname
  path        = var.instance_profile_path
  role        = aws_iam_role.coupang-primary-vault.name
}

resource "aws_iam_role" "coupang-primary-vault" {
  name_prefix        = "coupang-primary-vault"
  assume_role_policy = data.aws_iam_policy_document.assume.json
}

resource "aws_iam_role_policy" "coupang-primary-vault" {
  name   = "coupang-primary-vault"
  role   = aws_iam_role.coupang-primary-vault.id
  policy = data.aws_iam_policy_document.this.json
}
