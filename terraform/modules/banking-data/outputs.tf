output "lambda_function_names" {
  description = "Map of logical Lambda key -> function name."
  value       = { for k, f in aws_lambda_function.this : k => f.function_name }
}

output "glue_job_names" {
  description = "Map of logical Glue job key -> job name."
  value       = { for k, j in aws_glue_job.this : k => j.name }
}

output "glue_database_name" {
  description = "Shared Glue Catalog database."
  value       = aws_glue_catalog_database.this.name
}

output "athena_workgroup" {
  description = "Athena workgroup configured with the athena bucket as its output location."
  value       = aws_athena_workgroup.this.name
}
