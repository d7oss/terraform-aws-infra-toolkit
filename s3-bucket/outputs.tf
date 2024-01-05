output "name" {
  value = module.s3_bucket.s3_bucket_id
}

output "arn" {
  value = module.s3_bucket.s3_bucket_arn
}

output "contents_arn" {
  value = "${module.s3_bucket.s3_bucket_arn}/*"
}

output "regional_domain_name" {
  value = module.s3_bucket.s3_bucket_bucket_regional_domain_name
}
