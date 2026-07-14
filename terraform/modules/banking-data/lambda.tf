# Generic Lambda factory: every function declared in lambda.json gets
# created here. A function's own environment_variables always apply; if its
# JSON entry also sets glue_job_key, PROJECT_NAME/ENVIRONMENT/GLUE_JOB_KEY/
# RAW_KEY_PREFIX/CONFIG_KEY_PREFIX are additionally wired in automatically
# (this is what "event_handler" uses to resolve CONFIG_BUCKET/GLUE_JOB_NAME
# from SSM at cold start, rather than being handed the resolved values
# directly -- see lambda_function.py).

resource "aws_lambda_function" "this" {
  for_each = local.lambda_functions

  function_name = "${local.name_prefix}-${each.key}"
  description   = each.value.description
  role          = var.lambda_role_arn
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
        PROJECT_NAME      = var.project_name
        ENVIRONMENT       = var.environment
        GLUE_JOB_KEY      = each.value.glue_job_key
        RAW_KEY_PREFIX    = var.raw_key_prefix
        CONFIG_KEY_PREFIX = var.config_key_prefix
      } : {}
    )
  }

  tags = { Name = "${local.name_prefix}-${each.key}" }

  # Nothing in this resource references aws_ssm_parameter.glue_job_names or
  # data.aws_ssm_parameter.buckets directly anymore (the function reads them
  # itself at cold start via GLUE_JOB_KEY/PROJECT_NAME/ENVIRONMENT) -- without
  # an explicit depends_on, Terraform has no way to know this function
  # shouldn't be created before the SSM parameters it'll look up at runtime
  # exist.
  depends_on = [aws_ssm_parameter.glue_job_names]
}

resource "aws_lambda_permission" "allow_eventbridge" {
  for_each = { for k, r in local.eventbridge_rules : k => r if r.target.type == "lambda" }

  statement_id  = "AllowExecutionFromEventBridge"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.this[each.value.target.function_key].function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.this[each.key].arn
}
