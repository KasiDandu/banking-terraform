resource "aws_s3_bucket" "raw" {
  bucket = "${local.name_prefix}-raw-${data.aws_caller_identity.current.account_id}"
  tags   = { Name = "${local.name_prefix}-raw" }
}

resource "aws_s3_bucket" "config" {
  bucket = "${local.name_prefix}-config-${data.aws_caller_identity.current.account_id}"
  tags   = { Name = "${local.name_prefix}-config" }
}

resource "aws_s3_bucket" "data" {
  bucket = "${local.name_prefix}-data-${data.aws_caller_identity.current.account_id}"
  tags   = { Name = "${local.name_prefix}-data" }
}

resource "aws_s3_bucket" "cloudtrail_logs" {
  bucket = "${local.name_prefix}-cloudtrail-${data.aws_caller_identity.current.account_id}"
  tags   = { Name = "${local.name_prefix}-cloudtrail" }
}

resource "aws_s3_bucket" "athena_results" {
  bucket = "${local.name_prefix}-athena-results-${data.aws_caller_identity.current.account_id}"
  tags   = { Name = "${local.name_prefix}-athena-results" }
}

resource "aws_s3_bucket_policy" "cloudtrail_logs" {
  bucket = aws_s3_bucket.cloudtrail_logs.id
  policy = data.aws_iam_policy_document.cloudtrail_bucket.json
}
