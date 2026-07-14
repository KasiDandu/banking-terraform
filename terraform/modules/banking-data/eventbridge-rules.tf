# Generic EventBridge rule factory over eventbridge-rules.json's array
# (converted to a map keyed by rule name in main.tf's locals). Each rule is
# either:
#   - bucket_key -- this module auto-builds an S3 "Object Created" pattern
#     against that bucket (looked up via SSM, same as everywhere else in
#     this module -- this pipeline's real trigger, fed by the landing
#     bucket's native S3 -> EventBridge notifications enabled in the
#     buckets module), filtered by var.raw_key_prefix, or
#   - event_pattern -- a raw EventBridge pattern object, used as-is, or
#   - schedule_expression -- a cron/rate rule instead of an event pattern.
# Target is either an internally-managed Lambda (target.function_key) or
# any external ARN (target.arn, e.g. a Step Function), each with its own
# target.role_arn where the service needs one (e.g. Step Functions).

locals {
  eventbridge_event_patterns = {
    for name, rule in local.eventbridge_rules : name => (
      lookup(rule, "bucket_key", null) != null ? jsonencode({
        source      = ["aws.s3"]
        detail-type = ["Object Created"]
        detail = {
          bucket = { name = [data.aws_ssm_parameter.buckets[rule.bucket_key].value] }
          object = { key = [{ prefix = var.raw_key_prefix }] }
        }
      }) : lookup(rule, "event_pattern", null) != null ? jsonencode(rule.event_pattern) : null
    )
  }
}

resource "aws_cloudwatch_event_rule" "this" {
  for_each = local.eventbridge_rules

  name        = "${local.name_prefix}-${each.key}"
  description = lookup(each.value, "description", null)

  event_pattern       = local.eventbridge_event_patterns[each.key]
  schedule_expression = lookup(each.value, "schedule_expression", null)
}

resource "aws_cloudwatch_event_target" "this" {
  for_each = local.eventbridge_rules

  rule      = aws_cloudwatch_event_rule.this[each.key].name
  target_id = each.key

  arn = (
    each.value.target.type == "lambda" && lookup(each.value.target, "function_key", null) != null
    ? aws_lambda_function.this[each.value.target.function_key].arn
    : each.value.target.arn
  )

  role_arn = lookup(each.value.target, "role_arn", null)
}
