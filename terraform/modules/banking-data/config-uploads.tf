# Uploads the per-source schema configs (config/*.json) to the config
# bucket's config_key_prefix on every apply -- previously a manual `aws s3
# cp` step, easy to forget (and did get forgotten) whenever buckets/
# banking-data get destroyed and recreated. Same fileset() call as
# local.source_names in main.tf, which derives the Athena partition
# allowlist from these same filenames.
resource "aws_s3_object" "config_files" {
  for_each = fileset("${path.module}/config", "*.json")

  bucket = data.aws_ssm_parameter.buckets["config"].value
  key    = "${var.config_key_prefix}${each.value}"
  source = "${path.module}/config/${each.value}"
  etag   = filemd5("${path.module}/config/${each.value}")
}
