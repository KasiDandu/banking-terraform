data "aws_caller_identity" "current" {}

# Bucket names come from the buckets module via SSM Parameter Store lookup
# (not a Terraform reference or Terragrunt dependency) -- decouples this
# module from needing direct access to the buckets unit's state.
data "aws_ssm_parameter" "buckets" {
  for_each = toset(["landing", "config", "processed", "athena"])

  name = "/${var.project_name}/${var.environment}/buckets/${each.key}"
}

data "aws_iam_policy_document" "lambda_permissions" {
  statement {
    actions   = ["s3:GetObject"]
    resources = ["arn:aws:s3:::${data.aws_ssm_parameter.buckets["config"].value}/*"]
  }

  # Without s3:ListBucket, S3 returns 403 (not 404) for HeadObject/GetObject
  # on a key that simply doesn't exist -- indistinguishable from an actual
  # permissions problem. _config_exists()'s "no config for this source"
  # path relies on getting a real 404 back.
  statement {
    actions   = ["s3:ListBucket"]
    resources = ["arn:aws:s3:::${data.aws_ssm_parameter.buckets["config"].value}"]
  }

  statement {
    actions   = ["glue:StartJobRun"]
    resources = [for job in aws_glue_job.this : job.arn]
  }

  # event_handler resolves CONFIG_BUCKET/GLUE_JOB_NAME from these at cold
  # start (see lambda_function.py) rather than being handed the values
  # directly.
  statement {
    actions = ["ssm:GetParameter"]
    resources = [
      "arn:aws:ssm:${var.aws_region}:${data.aws_caller_identity.current.account_id}:parameter/${var.project_name}/${var.environment}/buckets/config",
      "arn:aws:ssm:${var.aws_region}:${data.aws_caller_identity.current.account_id}:parameter/${var.project_name}/${var.environment}/glue_jobs/*",
    ]
  }
}

data "aws_iam_policy_document" "glue_job_permissions" {
  statement {
    actions   = ["s3:GetObject"]
    resources = ["arn:aws:s3:::${data.aws_ssm_parameter.buckets["landing"].value}/*"]
  }

  statement {
    actions   = ["s3:GetObject"]
    resources = ["arn:aws:s3:::${data.aws_ssm_parameter.buckets["config"].value}/*"]
  }

  statement {
    actions = ["s3:GetObject", "s3:PutObject", "s3:DeleteObject", "s3:ListBucket"]
    resources = [
      "arn:aws:s3:::${data.aws_ssm_parameter.buckets["processed"].value}",
      "arn:aws:s3:::${data.aws_ssm_parameter.buckets["processed"].value}/*",
    ]
  }

  statement {
    actions   = ["s3:GetObject"]
    resources = ["arn:aws:s3:::${var.artifact_bucket}/*"]
  }

  statement {
    actions = [
      "glue:GetCrawler",
      "glue:CreateCrawler",
      "glue:UpdateCrawler",
      "glue:StartCrawler",
    ]
    resources = ["*"]
  }

  statement {
    actions   = ["iam:PassRole"]
    resources = [var.crawler_role_arn]
  }
}

data "aws_iam_policy_document" "crawler_permissions" {
  statement {
    actions = ["s3:GetObject", "s3:ListBucket"]
    resources = [
      "arn:aws:s3:::${data.aws_ssm_parameter.buckets["processed"].value}",
      "arn:aws:s3:::${data.aws_ssm_parameter.buckets["processed"].value}/*",
    ]
  }
}
