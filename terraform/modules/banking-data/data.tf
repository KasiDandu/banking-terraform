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

  statement {
    actions   = ["glue:StartJobRun"]
    resources = [for job in aws_glue_job.this : job.arn]
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
