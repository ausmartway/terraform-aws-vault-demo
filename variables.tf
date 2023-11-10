variable "hostname" {
  type    = string
  default = "vault"
}

variable "key_name" {
  type    = string
  default = "yulei"
}

variable "tags" {
  type = map(any)
  default = {
    Name        = "yulei-vault"
    TTL         = "192"
    owner       = "yulei@hashicorp.com"
    Region      = "APJ"
    description = "General vault demo instance"
  }
}

variable "instance_type" {
  type    = string
  default = "t3.small"
}

variable "instance_profile_path" {
  description = "Path in which to create the IAM instance profile."
  default     = "/"
}

variable "slack_webhook" {
  type    = string
  default = "https://hooks.slack.com/services/"
}

variable "private_ip" {
  type    = string
  default = "10.0.101.161"
}

variable "vault_license" {
  default = "YOURLICENSEFILE"
}