output "lambda_role_name" {
  value = aws_iam_role.lambda.name
}

output "lambda_role_arn" {
  value = aws_iam_role.lambda.arn
}

output "glue_job_role_name" {
  value = aws_iam_role.glue_job.name
}

output "glue_job_role_arn" {
  value = aws_iam_role.glue_job.arn
}

output "crawler_role_name" {
  value = aws_iam_role.crawler.name
}

output "crawler_role_arn" {
  value = aws_iam_role.crawler.arn
}
