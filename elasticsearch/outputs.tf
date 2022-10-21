output "url" {
  value = "https://${aws_elasticsearch_domain.main.endpoint}"
}
