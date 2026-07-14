output "bucket_names" {
  description = "Map of logical bucket key -> actual bucket name."
  value       = { for k, b in aws_s3_bucket.this : k => b.bucket }
}

output "bucket_arns" {
  description = "Map of logical bucket key -> bucket ARN."
  value       = { for k, b in aws_s3_bucket.this : k => b.arn }
}

output "ssm_parameter_names" {
  description = "Map of logical bucket key -> the SSM parameter name its bucket name is published under."
  value       = { for k, p in aws_ssm_parameter.buckets : k => p.name }
}
