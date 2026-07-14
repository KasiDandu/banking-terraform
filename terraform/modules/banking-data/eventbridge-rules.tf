# CloudTrail (S3 data events on the raw bucket) -> EventBridge -> Lambda

resource "aws_cloudtrail" "raw_bucket_events" {
  name                          = "${local.name_prefix}-raw-data-events"
  s3_bucket_name                = aws_s3_bucket.cloudtrail_logs.id
  include_global_service_events = false
  is_multi_region_trail         = false
  enable_logging                = true

  event_selector {
    read_write_type           = "WriteOnly"
    include_management_events = false

    data_resource {
      type   = "AWS::S3::Object"
      values = ["${aws_s3_bucket.raw.arn}/${var.raw_key_prefix}"]
    }
  }

  depends_on = [aws_s3_bucket_policy.cloudtrail_logs]
}

resource "aws_cloudwatch_event_rule" "raw_object_created" {
  name = "${local.name_prefix}-raw-object-created"

  event_pattern = jsonencode({
    source      = ["aws.s3"]
    detail-type = ["AWS API Call via CloudTrail"]
    detail = {
      eventSource = ["s3.amazonaws.com"]
      eventName   = ["PutObject", "CompleteMultipartUpload"]
      requestParameters = {
        bucketName = [aws_s3_bucket.raw.bucket]
      }
    }
  })
}

resource "aws_cloudwatch_event_target" "invoke_lambda" {
  rule      = aws_cloudwatch_event_rule.raw_object_created.name
  target_id = "invoke-lambda"
  arn       = aws_lambda_function.event_handler.arn
}
