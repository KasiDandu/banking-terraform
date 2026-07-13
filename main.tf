data "aws_caller_identity" "current" {}

locals {
  name_prefix = "${var.project_name}-${var.environment}"
  source_names = sort([
    for f in fileset("${path.module}/config", "*.json") : trimsuffix(f, ".json")
  ])
}

# ---------------------------------------------------------------------------
# Terraform state lock (S3 backend's dynamodb_table) -- bootstrapped via the
# AWS CLI before this resource block existed, then imported, since the S3
# backend must be able to acquire a lock in this table before it can run any
# operation on this very configuration, including creating the table itself.
# ---------------------------------------------------------------------------

resource "aws_dynamodb_table" "terraform_lock" {
  name         = "${local.name_prefix}-tfstate-lock"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }

  tags = { Name = "${local.name_prefix}-tfstate-lock" }
}

# ---------------------------------------------------------------------------
# S3 buckets
# ---------------------------------------------------------------------------

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

data "aws_iam_policy_document" "cloudtrail_bucket" {
  statement {
    sid       = "AWSCloudTrailAclCheck"
    actions   = ["s3:GetBucketAcl"]
    resources = [aws_s3_bucket.cloudtrail_logs.arn]

    principals {
      type        = "Service"
      identifiers = ["cloudtrail.amazonaws.com"]
    }
  }

  statement {
    sid       = "AWSCloudTrailWrite"
    actions   = ["s3:PutObject"]
    resources = ["${aws_s3_bucket.cloudtrail_logs.arn}/AWSLogs/${data.aws_caller_identity.current.account_id}/*"]

    principals {
      type        = "Service"
      identifiers = ["cloudtrail.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "s3:x-amz-acl"
      values   = ["bucket-owner-full-control"]
    }
  }
}

resource "aws_s3_bucket_policy" "cloudtrail_logs" {
  bucket = aws_s3_bucket.cloudtrail_logs.id
  policy = data.aws_iam_policy_document.cloudtrail_bucket.json
}

# ---------------------------------------------------------------------------
# Glue Catalog: shared database + fixed audit_lineage table
# ---------------------------------------------------------------------------

resource "aws_glue_catalog_database" "this" {
  name = var.glue_database_name
}

resource "aws_athena_workgroup" "this" {
  name = "${local.name_prefix}-athena"

  configuration {
    enforce_workgroup_configuration    = true
    publish_cloudwatch_metrics_enabled = true

    result_configuration {
      output_location = "s3://${aws_s3_bucket.athena_results.bucket}/"
    }
  }

  tags = { Name = "${local.name_prefix}-athena" }
}

resource "aws_glue_catalog_table" "audit_lineage" {
  name          = "audit_lineage"
  database_name = aws_glue_catalog_database.this.name
  table_type    = "EXTERNAL_TABLE"

  parameters = {
    classification              = "parquet"
    "projection.enabled"        = "true"
    "projection.source.type"    = "enum"
    "projection.source.values"  = join(",", local.source_names)
    "projection.dt.type"        = "date"
    "projection.dt.format"      = "yyyy-MM-dd"
    "projection.dt.range"       = "NOW-4YEARS,NOW+1DAYS"
    "storage.location.template" = "s3://${aws_s3_bucket.data.bucket}/audit/lineage/source=$${source}/dt=$${dt}/"
  }

  partition_keys {
    name = "source"
    type = "string"
  }
  partition_keys {
    name = "dt"
    type = "string"
  }

  storage_descriptor {
    location      = "s3://${aws_s3_bucket.data.bucket}/audit/lineage/"
    input_format  = "org.apache.hadoop.hive.ql.io.parquet.MapredParquetInputFormat"
    output_format = "org.apache.hadoop.hive.ql.io.parquet.MapredParquetOutputFormat"

    ser_de_info {
      serialization_library = "org.apache.hadoop.hive.ql.io.parquet.serde.ParquetHiveSerDe"
    }

    dynamic "columns" {
      for_each = {
        run_id                   = "string"
        source_name              = "string"
        raw_s3_bucket            = "string"
        raw_s3_key               = "string"
        config_s3_key            = "string"
        load_mode                = "string"
        target_s3_path           = "string"
        target_database          = "string"
        target_table             = "string"
        glue_job_name            = "string"
        glue_job_run_id          = "string"
        started_at               = "string"
        rows_read                = "bigint"
        rows_valid               = "bigint"
        rows_rejected            = "bigint"
        rejected_s3_path         = "string"
        finished_at              = "string"
        duration_seconds         = "double"
        status                   = "string"
        error_message            = "string"
        validation_error_summary = "string"
      }
      content {
        name = columns.key
        type = columns.value
      }
    }
  }
}

# ---------------------------------------------------------------------------
# IAM: Lambda event handler
# ---------------------------------------------------------------------------

data "aws_iam_policy_document" "lambda_assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "lambda" {
  name               = "${local.name_prefix}-lambda-role"
  assume_role_policy = data.aws_iam_policy_document.lambda_assume.json
}

resource "aws_iam_role_policy_attachment" "lambda_basic_execution" {
  role       = aws_iam_role.lambda.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

data "aws_iam_policy_document" "lambda_permissions" {
  statement {
    actions   = ["s3:GetObject"]
    resources = ["${aws_s3_bucket.config.arn}/*"]
  }

  statement {
    actions   = ["glue:StartJobRun"]
    resources = [aws_glue_job.etl.arn]
  }
}

resource "aws_iam_role_policy" "lambda_permissions" {
  name   = "${local.name_prefix}-lambda-permissions"
  role   = aws_iam_role.lambda.id
  policy = data.aws_iam_policy_document.lambda_permissions.json
}

# ---------------------------------------------------------------------------
# Lambda: EventBridge (CloudTrail S3 data event) handler
# ---------------------------------------------------------------------------

resource "aws_lambda_function" "event_handler" {
  function_name = "${local.name_prefix}-event-handler"
  role          = aws_iam_role.lambda.arn
  handler       = "lambda_function.handler"
  runtime       = var.lambda_runtime
  timeout       = 30

  s3_bucket = var.artifact_bucket
  s3_key    = var.lambda_s3_key

  environment {
    variables = {
      CONFIG_BUCKET     = aws_s3_bucket.config.bucket
      GLUE_JOB_NAME     = aws_glue_job.etl.name
      RAW_KEY_PREFIX    = var.raw_key_prefix
      CONFIG_KEY_PREFIX = var.config_key_prefix
      LOG_LEVEL         = "INFO"
    }
  }

  tags = { Name = "${local.name_prefix}-event-handler" }
}

resource "aws_lambda_permission" "allow_eventbridge" {
  statement_id  = "AllowExecutionFromEventBridge"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.event_handler.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.raw_object_created.arn
}

# ---------------------------------------------------------------------------
# CloudTrail (S3 data events on the raw bucket) -> EventBridge -> Lambda
# ---------------------------------------------------------------------------

resource "aws_cloudtrail" "raw_bucket_events" {
  name                          = "${local.name_prefix}-raw-data-events"
  s3_bucket_name                = aws_s3_bucket.cloudtrail_logs.id
  include_global_service_events = false
  is_multi_region_trail         = false
  enable_logging                = true

  event_selector {
    read_write_type           = "WriteOnly"
    include_management_events = false

    data_resource {
      type   = "AWS::S3::Object"
      values = ["${aws_s3_bucket.raw.arn}/${var.raw_key_prefix}"]
    }
  }

  depends_on = [aws_s3_bucket_policy.cloudtrail_logs]
}

resource "aws_cloudwatch_event_rule" "raw_object_created" {
  name = "${local.name_prefix}-raw-object-created"

  event_pattern = jsonencode({
    source      = ["aws.s3"]
    detail-type = ["AWS API Call via CloudTrail"]
    detail = {
      eventSource = ["s3.amazonaws.com"]
      eventName   = ["PutObject", "CompleteMultipartUpload"]
      requestParameters = {
        bucketName = [aws_s3_bucket.raw.bucket]
      }
    }
  })
}

resource "aws_cloudwatch_event_target" "invoke_lambda" {
  rule      = aws_cloudwatch_event_rule.raw_object_created.name
  target_id = "invoke-lambda"
  arn       = aws_lambda_function.event_handler.arn
}

# ---------------------------------------------------------------------------
# IAM: Glue job execution role
# ---------------------------------------------------------------------------

data "aws_iam_policy_document" "glue_assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["glue.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "glue_job" {
  name               = "${local.name_prefix}-glue-job-role"
  assume_role_policy = data.aws_iam_policy_document.glue_assume.json
}

resource "aws_iam_role_policy_attachment" "glue_job_service_role" {
  role       = aws_iam_role.glue_job.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSGlueServiceRole"
}

data "aws_iam_policy_document" "glue_job_permissions" {
  statement {
    actions   = ["s3:GetObject"]
    resources = ["${aws_s3_bucket.raw.arn}/*"]
  }

  statement {
    actions   = ["s3:GetObject"]
    resources = ["${aws_s3_bucket.config.arn}/*"]
  }

  statement {
    actions   = ["s3:GetObject", "s3:PutObject", "s3:DeleteObject", "s3:ListBucket"]
    resources = [aws_s3_bucket.data.arn, "${aws_s3_bucket.data.arn}/*"]
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
    resources = [aws_iam_role.crawler.arn]
  }
}

resource "aws_iam_role_policy" "glue_job_permissions" {
  name   = "${local.name_prefix}-glue-job-permissions"
  role   = aws_iam_role.glue_job.id
  policy = data.aws_iam_policy_document.glue_job_permissions.json
}

# ---------------------------------------------------------------------------
# IAM: crawler role (assumed by the crawlers the Glue job creates/refreshes)
# ---------------------------------------------------------------------------

resource "aws_iam_role" "crawler" {
  name               = "${local.name_prefix}-crawler-role"
  assume_role_policy = data.aws_iam_policy_document.glue_assume.json
}

resource "aws_iam_role_policy_attachment" "crawler_service_role" {
  role       = aws_iam_role.crawler.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSGlueServiceRole"
}

data "aws_iam_policy_document" "crawler_permissions" {
  statement {
    actions   = ["s3:GetObject", "s3:ListBucket"]
    resources = [aws_s3_bucket.data.arn, "${aws_s3_bucket.data.arn}/*"]
  }
}

resource "aws_iam_role_policy" "crawler_permissions" {
  name   = "${local.name_prefix}-crawler-permissions"
  role   = aws_iam_role.crawler.id
  policy = data.aws_iam_policy_document.crawler_permissions.json
}

# ---------------------------------------------------------------------------
# Glue ETL job
# ---------------------------------------------------------------------------

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

# ---------------------------------------------------------------------------
# SSM parameters (operational visibility for other consumers)
# ---------------------------------------------------------------------------

resource "aws_ssm_parameter" "raw_bucket" {
  name  = "/${var.project_name}/${var.environment}/raw_bucket"
  type  = "String"
  value = aws_s3_bucket.raw.bucket
}

resource "aws_ssm_parameter" "config_bucket" {
  name  = "/${var.project_name}/${var.environment}/config_bucket"
  type  = "String"
  value = aws_s3_bucket.config.bucket
}

resource "aws_ssm_parameter" "data_bucket" {
  name  = "/${var.project_name}/${var.environment}/data_bucket"
  type  = "String"
  value = aws_s3_bucket.data.bucket
}

resource "aws_ssm_parameter" "glue_job_name" {
  name  = "/${var.project_name}/${var.environment}/glue_job_name"
  type  = "String"
  value = aws_glue_job.etl.name
}
