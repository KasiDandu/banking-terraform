output "raw_bucket" {
  description = "Landing bucket for raw source files (raw/<source_name>/<file>)."
  value       = aws_s3_bucket.raw.bucket
}

output "config_bucket" {
  description = "Bucket holding per-source config JSON (config/<source_name>.json)."
  value       = aws_s3_bucket.config.bucket
}

output "data_bucket" {
  description = "Data lake bucket (processed/, audit/, rejected/)."
  value       = aws_s3_bucket.data.bucket
}

output "lambda_function_name" {
  description = "Name of the EventBridge handler Lambda."
  value       = aws_lambda_function.event_handler.function_name
}

output "glue_job_name" {
  description = "Name of the Glue ETL job."
  value       = aws_glue_job.etl.name
}

output "glue_database_name" {
  description = "Shared Glue Catalog database."
  value       = aws_glue_catalog_database.this.name
}

output "athena_results_bucket" {
  description = "Bucket Athena writes query results to."
  value       = aws_s3_bucket.athena_results.bucket
}

output "athena_workgroup" {
  description = "Athena workgroup configured with the results bucket as its output location."
  value       = aws_athena_workgroup.this.name
}
