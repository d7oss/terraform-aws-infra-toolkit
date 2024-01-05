module "cdn" {
  source = "terraform-aws-modules/cloudfront/aws"
  version = "~> 3.0"

  aliases = [var.domain]
  is_ipv6_enabled = true
  default_root_object = var.default_root_object

  # S3
  create_origin_access_control = true
  origin_access_control = {
    "s3" = {
      description = var.domain
      origin_type = "s3"
      signing_behavior = "always"
      signing_protocol = "sigv4"
    }
  }

  origin = {
    "s3" = {
      origin_access_control = "s3"
      domain_name = var.s3_bucket_regional_domain_name
    }

    # TODO: Add support for HTTP origins.
  }

  viewer_certificate = {
    acm_certificate_arn = var.tls_certificate_arn
    ssl_support_method = "sni-only"
  }

  default_cache_behavior = {
    target_origin_id = "s3"
    allowed_methods = ["GET", "HEAD", "OPTIONS", "PUT", "POST", "PATCH", "DELETE"]
    cached_methods = ["GET", "HEAD", "OPTIONS"]
    viewer_protocol_policy = "redirect-to-https"
    origin_request_policy_id = data.aws_cloudfront_origin_request_policy.aws_managed["Managed-CORS-S3Origin"].id
    cache_policy_id = data.aws_cloudfront_cache_policy.aws_managed["Managed-CachingDisabled"].id
    use_forwarded_values = false
  }

  ordered_cache_behavior = [
    for path_pattern, behavior in var.behaviors_by_path: {
      target_origin_id = "s3"
      path_pattern = path_pattern
      allowed_methods = behavior.allowed_methods
      cached_methods = behavior.cached_methods
      viewer_protocol_policy = "redirect-to-https"
      origin_request_policy_id = data.aws_cloudfront_origin_request_policy.aws_managed["Managed-CORS-S3Origin"].id
      cache_policy_id = (behavior.cache
        ? data.aws_cloudfront_cache_policy.aws_managed["Managed-CachingOptimized"].id
        : data.aws_cloudfront_cache_policy.aws_managed["Managed-CachingDisabled"].id
      )
      use_forwarded_values = false
      compress = behavior.compress
      query_string = behavior.query_string
    }
  ]
}
