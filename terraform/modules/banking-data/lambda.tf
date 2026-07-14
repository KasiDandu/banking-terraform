resource "aws_lambda_function" "event_handler" {
  function_name = "${local.name_prefix}-event-handler"
  role          = aws_iam_role.lambda.arn
  handler       = "lambda_function.handler"
  runtime       = var.lambda_runtime
  timeout       = 30

  s3_bucket = var.artifact_bucket
  s3_key    = var.lambda_s3_key

  environment {
    variables = {
      CONFIG_BUCKET     = aws_s3_bucket.config.bucket
      GLUE_JOB_NAME     = aws_glue_job.etl.name
      RAW_KEY_PREFIX    = var.raw_key_prefix
      CONFIG_KEY_PREFIX = var.config_key_prefix
      LOG_LEVEL         = "INFO"
    }
  }

  tags = { Name = "${local.name_prefix}-event-handler" }
}

resource "aws_lambda_permission" "allow_eventbridge" {
  statement_id  = "AllowExecutionFromEventBridge"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.event_handler.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.raw_object_created.arn
}
