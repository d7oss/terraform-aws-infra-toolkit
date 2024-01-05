output "domain_name" {
  value = module.cdn.cloudfront_distribution_domain_name
}

output "zone_id" {
  value = module.cdn.cloudfront_distribution_hosted_zone_id
}

output "arn" {
  value = module.cdn.cloudfront_distribution_arn
}
