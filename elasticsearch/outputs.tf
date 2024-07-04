output "hostname" {
  value = local.hostname
}

output "url" {
  value = "https://${local.hostname}"
}

output "url_with_credentials" {
  value = var.enable_authentication ? format("https://%s:%s@%s", [
    var.master_username,
    urlencode(one(random_password.main.*.result)),
    local.hostname,
  ]...) : null
}

output "kibana_url" {
  value = "https://${replace(aws_elasticsearch_domain.main.kibana_endpoint, aws_elasticsearch_domain.main.endpoint, local.hostname)}"
}
