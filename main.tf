data "terraform_remote_state" "this" {
  backend = "remote"

  config = {
    organization = "yulei"
    workspaces = {
      name = "aws-shared-infra"
    }
  }
}

locals {
  public_subnets          = data.terraform_remote_state.this.outputs.public_subnets
  private_subnets         = data.terraform_remote_state.this.outputs.private_subnets
  security_group_outbound = data.terraform_remote_state.this.outputs.security_group_outbound
  security_group_ssh      = data.terraform_remote_state.this.outputs.security_group_ssh
  vpc_id                  = data.terraform_remote_state.this.outputs.vpc_id
  kms_key_id              = data.terraform_remote_state.this.outputs.unseal_key_id
}

data "aws_route53_zone" "this" {
  name         = "yulei.sbx.hashidemos.io"
  private_zone = false
}

data "aws_ami" "ubuntu" {
  most_recent = true

  filter {
    name   = "tag:application"
    values = ["vault-1.15.2-ent"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = ["384224972042"] # HashiCorp SE Yulei Liu account
}

module "vault" {
  source  = "terraform-aws-modules/ec2-instance/aws"
  version = "5.3.1"

  name = var.hostname

  private_ip = var.private_ip

  user_data_base64 = base64gzip(local.user_data)

  ami                         = data.aws_ami.ubuntu.id
  instance_type               = var.instance_type
  key_name                    = var.key_name
  iam_instance_profile        = aws_iam_instance_profile.vault.name
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

resource "aws_route53_record" "this" {
  zone_id = data.aws_route53_zone.this.id
  name    = "${var.hostname}.${data.aws_route53_zone.this.name}"
  type    = "A"
  ttl     = "300"
  records = [module.vault.public_ip]
}

module "security_group_vault" {
  source = "terraform-aws-modules/security-group/aws"

  name        = "vault-ports"
  description = "vault api/cluster/kmip access"
  vpc_id      = local.vpc_id

  ingress_with_cidr_blocks = [
    {
      from_port   = 8200
      to_port     = 8200
      protocol    = "tcp"
      description = "Vault ingress api addr"
      cidr_blocks = "0.0.0.0/0"
    },
    {
      from_port   = 8201
      to_port     = 8201
      protocol    = "tcp"
      description = "Vault ingress cluster addr"
      cidr_blocks = "0.0.0.0/0"
    },
    {
      from_port   = 5696
      to_port     = 5696
      protocol    = "tcp"
      description = "Vault KMIP listening port"
      cidr_blocks = "0.0.0.0/0"
    }
  ]
  tags = var.tags
}

module "security_group_vault_from_public_subnets_to_private_subnets" {
  source = "terraform-aws-modules/security-group/aws"

  name        = "vault_from_public_subnets_to_private_subnets"
  description = "vault api/cluster/kmip access"
  vpc_id      = local.vpc_id

  ingress_with_cidr_blocks = [
    {
      from_port   = 8200
      to_port     = 8200
      protocol    = "tcp"
      description = "Vault ingress api addr"
      cidr_blocks = "10.0.0.0/16"
    },
    {
      from_port   = 8201
      to_port     = 8201
      protocol    = "tcp"
      description = "Vault ingress cluster addr"
      cidr_blocks = "10.0.0.0/16"
    },
    {
      from_port   = 5696
      to_port     = 5696
      protocol    = "tcp"
      description = "Vault KMIP listening port"
      cidr_blocks = "10.0.0.0/16"
    }
  ]
  tags = var.tags
}

data "aws_iam_policy_document" "assume" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

data "aws_iam_policy_document" "this" {
  statement {
    actions = [
      "ec2:DescribeInstances",
      "ec2:DescribeTags",
      "iam:GetInstanceProfile",
      "iam:CreateUser",
      "iam:PutUserPolicy",
      "iam:CreateAccessKey",
      "iam:ListGroupsForUser",
      "iam:ListUserPolicies",
      "iam:ListAttachedUserPolicies",
      "iam:ListAccessKeys",
      "iam:DeleteAccessKey",
      "iam:DeleteUserPolicy",
      "iam:DeleteUser",
      "iam:GetUser",
      "iam:GetRole",
      "sts:GetFederationToken",
      "autoscaling:DescribeAutoScalingGroups",
      "kms:Encrypt",
      "kms:Decrypt",
      "kms:DescribeKey"
    ]
    resources = ["*"]
  }
}


resource "aws_iam_instance_profile" "vault" {
  name_prefix = var.hostname
  path        = var.instance_profile_path
  role        = aws_iam_role.vault.name
}

resource "aws_iam_role" "vault" {
  name_prefix        = var.hostname
  assume_role_policy = data.aws_iam_policy_document.assume.json
}

resource "aws_iam_role_policy" "vault" {
  name   = var.hostname
  role   = aws_iam_role.vault.id
  policy = data.aws_iam_policy_document.this.json
}


# resource "aws_kms_key" vault_unseal_key" {
#   description             = "Vault unseal key"
#   deletion_window_in_days = 10
#   tags                    = var.tags
# }

# resource "aws_volume_attachment" "vault" {
#   device_name = "/dev/sdh"
#   volume_id   = aws_ebs_volume.vault.id
#   instance_id = module.vault.id
# }

# resource "aws_ebs_volume" "vault" {
#   availability_zone = module.vault.availability_zone
#   size              = 50

#   tags = var.tags
# }

