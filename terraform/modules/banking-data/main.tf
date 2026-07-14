locals {
  name_prefix = "${var.project_name}-${var.environment}"
  source_names = sort([
    for f in fileset("${path.module}/config", "*.json") : trimsuffix(f, ".json")
  ])

  buckets          = var.buckets.with_terraform_buckets
  lambda_functions = var.lambda_functions
  glue_jobs        = var.glue_jobs

  # eventbridge-rules.json is a JSON array (each rule carries its own name),
  # keyed here by that name so it can drive a Terraform for_each.
  eventbridge_rules = { for r in var.eventbridge_rules : r.name => r }
}

# ---------------------------------------------------------------------------
# Terraform state lock (S3 backend's dynamodb_table) -- bootstrapped via the
# AWS CLI (or terraform/backend, see that root's README) before this resource
# block existed, then imported, since the S3 backend must be able to acquire
# a lock in this table before it can run any operation on this very
# configuration, including creating the table itself.
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
# Glue Catalog: shared database + fixed audit_lineage table + Athena
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
      output_location = "s3://${aws_s3_bucket.this["athena"].bucket}/"
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
    "storage.location.template" = "s3://${aws_s3_bucket.this["processed"].bucket}/audit/lineage/source=$${source}/dt=$${dt}/"
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
    location      = "s3://${aws_s3_bucket.this["processed"].bucket}/audit/lineage/"
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
# SSM parameters (operational visibility for other consumers)
# ---------------------------------------------------------------------------

resource "aws_ssm_parameter" "buckets" {
  for_each = local.buckets

  name  = "/${var.project_name}/${var.environment}/buckets/${each.key}"
  type  = "String"
  value = aws_s3_bucket.this[each.key].bucket
}

resource "aws_ssm_parameter" "glue_job_names" {
  for_each = local.glue_jobs

  name  = "/${var.project_name}/${var.environment}/glue_jobs/${each.key}"
  type  = "String"
  value = aws_glue_job.this[each.key].name
}
