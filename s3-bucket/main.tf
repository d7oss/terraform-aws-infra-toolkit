module "s3_bucket" {
  source = "terraform-aws-modules/s3-bucket/aws"
  version = "~> 3.0"

  bucket = var.name

  attach_policy = true
  policy = var.policy

  versioning = {
    enabled = var.enable_versioning
  }

  lifecycle_rule = [
    {  # Use S3's Intelligent Tiering to save storage cost
      # https://aws.amazon.com/s3/storage-classes/intelligent-tiering/
      id = "cost-saving"
      enabled = true
      transition = [
        { days = 15, storage_class = "INTELLIGENT_TIERING" },
      ]
    },
  ]

  cors_rule = var.cors_rules
}
