# Role creation (trust policy + baseline managed policy) lives in the iam
# module; var.lambda_role_name/glue_job_role_name/crawler_role_name are
# populated via a Terragrunt `dependency` block on that unit's outputs.
# This module only attaches the custom, service-specific permissions each
# role actually needs.

resource "aws_iam_role_policy" "lambda_permissions" {
  name   = "${local.name_prefix}-lambda-permissions"
  role   = var.lambda_role_name
  policy = data.aws_iam_policy_document.lambda_permissions.json
}

resource "aws_iam_role_policy" "glue_job_permissions" {
  name   = "${local.name_prefix}-glue-job-permissions"
  role   = var.glue_job_role_name
  policy = data.aws_iam_policy_document.glue_job_permissions.json
}

resource "aws_iam_role_policy" "crawler_permissions" {
  name   = "${local.name_prefix}-crawler-permissions"
  role   = var.crawler_role_name
  policy = data.aws_iam_policy_document.crawler_permissions.json
}
