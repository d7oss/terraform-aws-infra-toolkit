module "s3_bucket" {
  source = "../s3-bucket"

  name = "${var.hostname}-origin"
  enable_versioning = false

  policy = data.aws_iam_policy_document.grant_cdn_access_to_s3_bucket_files.json

  cors_rules = [
    {
      allowed_methods = ["GET"]
      allowed_origins = [var.hostname]
    },
  ]
}

module "cdn" {
  source = "../cdn"

  domain = var.hostname
  tls_certificate_arn = module.tls_certificate.arn
  s3_bucket_regional_domain_name = module.s3_bucket.regional_domain_name
  default_root_object = var.default_root_object

  behaviors_by_path = {
    "/*" = {
      allowed_methods = ["GET", "HEAD", "OPTIONS"]
      cached_methods = ["GET", "HEAD"]
      compress = true
      query_string = true
      cache = true
    }
  }
}

module "tls_certificate" {
  source = "../tls-certificate"

  domain_name = var.hostname
  zone_id = var.zone_id
}

module "dns_record" {
  source = "d7oss/route53/aws//record"
  version = "~> 1.0"

  zone_id = var.zone_id
  type = "A"
  name = var.hostname
  alias = {
    name = module.cdn.domain_name
    zone_id = module.cdn.zone_id
    evaluate_target_health = false
  }
}
