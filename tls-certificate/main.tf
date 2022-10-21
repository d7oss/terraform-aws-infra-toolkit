module "tls_certificate" {
  source = "terraform-aws-modules/acm/aws"
  version = "~> v2.0"

  domain_name = var.domain_name
  zone_id = var.zone_id
  subject_alternative_names = ["*.${var.domain_name}"]
}
