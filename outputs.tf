output "cluster_url" {
    value= "http://${aws_route53_record.this.name}:8200"
}
