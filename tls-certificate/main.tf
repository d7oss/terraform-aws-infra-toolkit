module "tls_certificate" {
  source = "terraform-aws-modules/acm/aws"
  version = "~> v5.0"

  domain_name = var.domain_name
  subject_alternative_names = ["*.${var.domain_name}"]

  validation_method = "DNS"
  zone_id = var.zone_id
}
