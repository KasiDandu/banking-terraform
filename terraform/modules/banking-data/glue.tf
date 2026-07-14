resource "aws_glue_job" "etl" {
  name         = "${local.name_prefix}-etl"
  role_arn     = aws_iam_role.glue_job.arn
  glue_version = var.glue_version

  worker_type       = var.glue_worker_type
  number_of_workers = var.glue_number_of_workers
  max_retries       = 0
  timeout           = var.glue_timeout_minutes

  command {
    name            = "glueetl"
    script_location = "s3://${var.artifact_bucket}/${var.glue_script_s3_key}"
    python_version  = "3"
  }

  default_arguments = {
    "--job-language"     = "python"
    "--DATA_BUCKET"      = aws_s3_bucket.data.bucket
    "--CRAWLER_ROLE_ARN" = aws_iam_role.crawler.arn
    "--extra-py-files"   = "s3://${var.artifact_bucket}/${var.glue_common_s3_key}"
    "--TempDir"          = "s3://${aws_s3_bucket.data.bucket}/glue-temp/"
  }

  tags = { Name = "${local.name_prefix}-etl" }
}
