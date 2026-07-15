data "aws_caller_identity" "current" {}

locals {
  name_prefix = "${var.project_name}-${var.environment}"
  buckets     = var.buckets.with_terraform_buckets
}

# Generic bucket factory: any bucket declared in buckets.json's
# with_terraform_buckets map gets created here, named
# "<project>-<environment>-<bucket_suffix>-<account_id>". Every bucket's
# name is published to SSM (see ssm.tf) so other modules (compute: lambda,
# glue) can look it up by logical key without a direct Terraform reference
# or Terragrunt dependency on this module.
resource "aws_s3_bucket" "this" {
  for_each = local.buckets

  bucket        = "${local.name_prefix}-${each.value.bucket_suffix}-${data.aws_caller_identity.current.account_id}"
  force_destroy = var.force_destroy
  tags          = { Name = "${local.name_prefix}-${each.value.bucket_suffix}" }
}

# Native S3 -> EventBridge notifications (replaces a CloudTrail data-events
# trail + its own logging bucket -- cheaper, lower latency, one less
# resource to manage). Every "Object Created" event on this bucket gets
# published to the default event bus; the compute module's
# eventbridge-rules.tf filters it.
resource "aws_s3_bucket_notification" "this" {
  for_each = var.eventbridge_bucket_key != null ? { (var.eventbridge_bucket_key) = true } : {}

  bucket      = aws_s3_bucket.this[each.key].id
  eventbridge = true
}
