data "aws_iam_user" "cicd" {
  user_name = "cicd"
}

data "aws_subnets" "private" {
  tags = { Tier = "private" }

  filter {
    name = "vpc-id"
    values = [var.vpc]
  }
}

data "aws_security_group" "http_load_balancers" {
  for_each = local.http_services
  name = "lb-${each.value.load_balancer}"
}

data "aws_route53_zone" "main" {
  name = var.dns_zone_domain
}

data "aws_acm_certificate" "main" {
  count = var.manage_tls ? 0 : 1
  domain = var.certificate_domain
}

data "aws_acm_certificate" "cdn" {
  provider = aws.use1
  count = var.manage_tls ? 0 : 1
  domain = var.certificate_domain
}

data "aws_cloudfront_cache_policy" "caching_disabled" {
  name = "Managed-CachingDisabled"
}

data "aws_cloudfront_cache_policy" "caching_optimized" {
  name = "Managed-CachingOptimized"
}

data "aws_cloudfront_origin_request_policy" "all_viewer" {
  name = "Managed-AllViewer"
}
