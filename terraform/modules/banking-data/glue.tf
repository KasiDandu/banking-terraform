# Generic Glue job factory: every job declared in glue.json gets created
# here. --DATA_BUCKET/--CRAWLER_ROLE_ARN/--TempDir/--extra-py-files are
# always wired in (every job needs them to use common/), merged with
# whatever job-specific default_arguments its JSON entry adds.

resource "aws_glue_job" "this" {
  for_each = local.glue_jobs

  name         = "${local.name_prefix}-${each.key}"
  description  = each.value.description
  role_arn     = aws_iam_role.glue_job.arn
  glue_version = each.value.glue_version

  worker_type       = each.value.worker_type
  number_of_workers = each.value.number_of_workers
  max_retries       = each.value.max_retries
  timeout           = each.value.timeout

  command {
    name            = "glueetl"
    script_location = "s3://${var.artifact_bucket}/${var.glue_script_s3_keys[each.key]}"
    python_version  = each.value.python_version
  }

  default_arguments = merge(
    each.value.default_arguments,
    {
      "--DATA_BUCKET"      = aws_s3_bucket.this["processed"].bucket
      "--CRAWLER_ROLE_ARN" = aws_iam_role.crawler.arn
      "--extra-py-files"   = "s3://${var.artifact_bucket}/${var.glue_common_s3_key}"
      "--TempDir"          = "s3://${aws_s3_bucket.this["processed"].bucket}/glue-temp/"
    }
  )

  tags = { Name = "${local.name_prefix}-${each.key}" }
}
