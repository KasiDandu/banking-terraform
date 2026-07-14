# Generic bucket factory: any bucket declared in buckets.json's
# with_terraform_buckets map gets created here, named
# "<project>-<environment>-<bucket_suffix>-<account_id>". Other resources
# reference a specific bucket by its logical key, e.g.
# aws_s3_bucket.this["landing"].
#
# This pipeline's actual roles: "landing" (S3 upload trigger source),
# "config" (per-source JSON), "processed" (Glue output: processed/
# rejected/audit prefixes), "athena" (Athena query results).

resource "aws_s3_bucket" "this" {
  for_each = local.buckets

  bucket = "${local.name_prefix}-${each.value.bucket_suffix}-${data.aws_caller_identity.current.account_id}"
  tags   = { Name = "${local.name_prefix}-${each.value.bucket_suffix}" }
}

# Native S3 -> EventBridge notifications on the landing bucket (replaces a
# CloudTrail data-events trail + its own logging bucket -- cheaper, lower
# latency, and one less resource to manage). Every "Object Created" event
# gets published to the default event bus; eventbridge-rules.tf filters it.
resource "aws_s3_bucket_notification" "landing" {
  bucket      = aws_s3_bucket.this["landing"].id
  eventbridge = true
}
