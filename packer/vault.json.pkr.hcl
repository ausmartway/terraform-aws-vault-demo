
variable "aws_access_key" {
  type    = string
  default = "${env("AWS_ACCESS_KEY_ID")}"
}

variable "aws_region" {
  type    = string
  default = "${env("AWS_REGION")}"
}

variable "aws_secret_key" {
  type    = string
  default = "${env("AWS_SECRET_ACCESS_KEY")}"
}

variable "aws_sessio_token" {
  type    = string
  default = "${env("AWS_SESSION_TOKEN")}"
}

variable "vault_version" {
  type    = string
  default = "1.16.9"
}

packer {
  required_plugins {
    amazon = {
      source  = "github.com/hashicorp/amazon"
      version = "~> 1"
    }
  }
}

data "amazon-ami" "ubuntu18" {
  filters = {
    name                = "ubuntu/images/*ubuntu-bionic-18.04-amd64-server-*"
    root-device-type    = "ebs"
    virtualization-type = "hvm"
  }
  most_recent = true
  owners      = ["099720109477"]  //ubuntu official account
}

locals {
  packerstarttime = replace(formatdate("YYYY-MM-DD-hh-mm", timestamp()),"-","")
}

source "amazon-ebs" "vault" {
  ami_name      = "awx-${local.packerstarttime}"
  instance_type = "t2.small"
  source_ami    = "${data.amazon-ami.ubuntu18.id}"
  ssh_username  = "ubuntu"
  tags = {
    Base_AMI_Name = "{{ .SourceAMIName }}"
    application   = "vault-${var.vault_version}"
    owner         = "Yulei Liu"
  }
}

build {
  sources = ["source.amazon-ebs.vault"]

  provisioner "file" {
    destination = "/tmp/vault.service"
    source      = "vault.service"
  }

  provisioner "shell" {
    inline = [
      "sleep 30", 
      "sudo apt-get update", 
      "sudo apt-get install -y unzip", 
      "wget https://releases.hashicorp.com/vault/${var.vault_version}+ent/vault_${var.vault_version}+ent_linux_amd64.zip", 
      "unzip vault_${var.vault_version}+ent_linux_amd64.zip", 
      "sudo cp vault /usr/local/bin", 
      "rm vault_${var.vault_version}+ent_linux_amd64.zip vault TermsOfEvaluation.txt EULA.txt", 
      "sudo groupadd vault", 
      "sudo useradd vault -g vault", 
      "sudo chown vault:vault /usr/local/bin/vault", 
      "sudo cp /tmp/vault.service /etc/systemd/system/vault.service", 
      "sudo chmod 0644 /etc/systemd/system/vault.service", 
      "sudo mkdir -p /opt/vault/data", 
      "sudo chown -Rf vault:vault /opt/vault", 
      "sudo systemctl disable vault"
    ]
  }

}
