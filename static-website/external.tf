data "aws_iam_policy_document" "grant_cdn_access_to_s3_bucket_files" {
  statement {  # CDN can read files
    actions = ["s3:GetObject"]
    resources = [module.s3_bucket.contents_arn]

    principals {
      type = "Service"
      identifiers = ["cloudfront.amazonaws.com"]
    }

    condition {
      test = "StringEquals"
      variable = "aws:SourceArn"
      values = [module.cdn.arn]
    }
  }
}
