module "apa-vault" {
  source  = "terraform-aws-modules/ec2-instance/aws"
  version = "5.3.1"

  name           = "apa-vault"

  private_ip = "10.0.101.162"

  user_data_base64 = base64gzip(data.template_file.userdata.rendered)

  ami                  = data.aws_ami.ubuntu.id
  instance_type        = var.instance_type
  key_name             = var.key_name
  iam_instance_profile = aws_iam_instance_profile.this.name
  associate_public_ip_address = true

  monitoring = true
  vpc_security_group_ids = [
    local.security_group_outbound,
    local.security_group_ssh,
    module.security_group_vault.security_group_id
  ]

  subnet_id = local.public_subnets[0]
  tags      = var.tags
}

resource "aws_route53_record" "apa-vault" {
  zone_id = data.aws_route53_zone.this.id
  name    = "apa-vault.${data.aws_route53_zone.this.name}"
  type    = "A"
  ttl     = "300"
  records = [module.apa-vault.public_ip]
}