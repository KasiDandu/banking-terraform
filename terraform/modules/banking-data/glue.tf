# Generic Glue job factory: every job declared in glue.json gets created
# here. --DATA_BUCKET/--CRAWLER_ROLE_ARN/--TempDir/--extra-py-files are
# always wired in (every job needs them to use common/), merged with
# whatever job-specific default_arguments its JSON entry adds.

resource "aws_glue_job" "this" {
  for_each = local.glue_jobs

  name         = "${local.name_prefix}-${each.key}"
  description  = each.value.description
  role_arn     = var.glue_job_role_arn
  glue_version = each.value.glue_version

  worker_type       = each.value.worker_type
  number_of_workers = each.value.number_of_workers
  max_retries       = each.value.max_retries
  timeout           = each.value.timeout

  # Defaults to Glue's own default of 1 if unset in JSON, which silently
  # serializes every run of a job -- discovered live: 3 files landing within
  # seconds of each other triggered ConcurrentRunsExceededException for two
  # of them, relying on EventBridge's Lambda retry/backoff to eventually
  # get them through instead of running them properly in parallel.
  execution_property {
    max_concurrent_runs = lookup(each.value, "max_concurrent_runs", 1)
  }

  command {
    name            = "glueetl"
    script_location = "s3://${var.artifact_bucket}/${var.glue_script_s3_keys[each.key]}"
    python_version  = each.value.python_version
  }

  default_arguments = merge(
    each.value.default_arguments,
    {
      "--DATA_BUCKET"      = data.aws_ssm_parameter.buckets["processed"].value
      "--CRAWLER_ROLE_ARN" = var.crawler_role_arn
      "--extra-py-files"   = "s3://${var.artifact_bucket}/${var.glue_common_s3_key}"
      "--TempDir"          = "s3://${data.aws_ssm_parameter.buckets["processed"].value}/glue-temp/"
    }
  )

  tags = { Name = "${local.name_prefix}-${each.key}" }
}
