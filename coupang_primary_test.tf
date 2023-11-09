variable "customer-poc-tags" {
  type = map(any)
  default = {
    Name        = "coupang-primary-test"
    TTL         = "192"
    owner       = "yulei@hashicorp.com"
    Region      = "APJ"
    description = "General vault demo instance"
  }
}

resource "aws_lb" "coupang-primary-test" {
  name               = "coupang-primary-test-nlb"
  internal           = false
  load_balancer_type = "network"
  subnets            = [local.public_subnets[0]]

  enable_deletion_protection = false

  tags = var.customer-poc-tags
  security_groups = [  
    local.security_group_outbound,
    local.security_group_ssh,
    module.security_group_vault.security_group_id,]
}

resource "aws_lb_target_group" "coupang-primary-test" {
  name     = "coupang-primary-test"
  port     = 8200
  protocol = "TCP"
  
  health_check {
    path = "/v1/sys/health?standbyok=true"
    port = "8200"
    protocol = "HTTP"
    timeout = 1
    interval = 3
  }

  vpc_id      = local.vpc_id
  depends_on = [ aws_lb.coupang-primary-test ]
}

resource "aws_lb_listener" "coupang-primary-test" {
  load_balancer_arn = aws_lb.coupang-primary-test.arn
  port              = "8200"
  protocol          = "TCP"

  default_action {
    target_group_arn = aws_lb_target_group.coupang-primary-test.arn
    type             = "forward"
  }
}

resource "aws_lb_target_group_attachment" "coupang-primary-test" {
  target_group_arn = aws_lb_target_group.coupang-primary-test.arn
  target_id        = module.coupang-primary-test.id
  port             = 8200
}

module "coupang-primary-test" {
  source  = "terraform-aws-modules/ec2-instance/aws"
  version = "5.3.1"

  name           = "coupang-primary-test"

  private_ip = "10.0.101.163"

  user_data_base64 = base64gzip(local.user_data )

  ami                  = data.aws_ami.ubuntu.id
  instance_type        = var.instance_type
  key_name             = var.key_name
  iam_instance_profile = aws_iam_instance_profile.coupang-primary-test.name
  associate_public_ip_address = false

  monitoring = true
  vpc_security_group_ids = [
    local.security_group_outbound,
    local.security_group_ssh,
    module.security_group_vault_from_public_subnets.security_group_id
  ]

  subnet_id = local.public_subnets[0]
  tags      = var.customer-poc-tags
}

# resource "aws_route53_record" "coupang-primary-test" {
#   zone_id = data.aws_route53_zone.this.id
#   name    = "coupang-primary-test.${data.aws_route53_zone.this.name}"
#   type    = "A"
#   ttl     = "300"
#   records = [module.coupang-primary-test.public_ip]
# }

output "coupang-primary-testc_cluster_url" {
  value = aws_lb.coupang-primary-test.dns_name
}

# output "coupang-primary-testc_cluster_url-direct" {
#   value = aws_route53_record.coupang-primary-test.name
# }

resource "aws_iam_instance_profile" "coupang-primary-test" {
  name_prefix = var.hostname
  path        = var.instance_profile_path
  role        = aws_iam_role.coupang-primary-test.name
}

resource "aws_iam_role" "coupang-primary-test" {
  name_prefix        = "coupang-primary-test"
  assume_role_policy = data.aws_iam_policy_document.assume.json
}

resource "aws_iam_role_policy" "coupang-primary-test" {
  name   = "coupang-primary-test"
  role   = aws_iam_role.coupang-primary-test.id
  policy = data.aws_iam_policy_document.this.json
}
