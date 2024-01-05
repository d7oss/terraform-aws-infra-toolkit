data "aws_cloudfront_cache_policy" "aws_managed" {
  for_each = toset([
    "Managed-CachingDisabled",
    "Managed-CachingOptimized",
  ])

  name = each.key
}

data "aws_cloudfront_origin_request_policy" "aws_managed" {
  for_each = toset([
    "Managed-CORS-S3Origin",
  ])

  name = each.key
}
