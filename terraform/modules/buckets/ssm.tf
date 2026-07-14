resource "aws_ssm_parameter" "buckets" {
  for_each = local.buckets

  name  = "/${var.project_name}/${var.environment}/buckets/${each.key}"
  type  = "String"
  value = aws_s3_bucket.this[each.key].bucket
}
