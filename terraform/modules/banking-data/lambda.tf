# Generic Lambda factory: every function declared in lambda.json gets
# created here. A function's own environment_variables always apply; if its
# JSON entry also sets glue_job_key, CONFIG_BUCKET/GLUE_JOB_NAME/
# RAW_KEY_PREFIX/CONFIG_KEY_PREFIX are additionally wired in automatically
# (this is what "event_handler" uses to know which Glue job to start).

resource "aws_lambda_function" "this" {
  for_each = local.lambda_functions

  function_name = "${local.name_prefix}-${each.key}"
  description   = each.value.description
  role          = aws_iam_role.lambda.arn
  handler       = each.value.handler
  runtime       = each.value.runtime
  memory_size   = each.value.memory_size
  timeout       = each.value.timeout

  reserved_concurrent_executions = each.value.reserved_concurrent_executions

  s3_bucket = var.artifact_bucket
  s3_key    = var.lambda_s3_keys[each.key]

  environment {
    variables = merge(
      each.value.environment_variables,
      lookup(each.value, "glue_job_key", null) != null ? {
        CONFIG_BUCKET     = aws_s3_bucket.this["config"].bucket
        GLUE_JOB_NAME     = aws_glue_job.this[each.value.glue_job_key].name
        RAW_KEY_PREFIX    = var.raw_key_prefix
        CONFIG_KEY_PREFIX = var.config_key_prefix
      } : {}
    )
  }

  tags = { Name = "${local.name_prefix}-${each.key}" }
}

resource "aws_lambda_permission" "allow_eventbridge" {
  for_each = { for k, r in local.eventbridge_rules : k => r if r.target.type == "lambda" }

  statement_id  = "AllowExecutionFromEventBridge"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.this[each.value.target.function_key].function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.this[each.key].arn
}
