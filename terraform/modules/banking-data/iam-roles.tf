# IAM: Lambda event handler

resource "aws_iam_role" "lambda" {
  name               = "${local.name_prefix}-lambda-role"
  assume_role_policy = data.aws_iam_policy_document.lambda_assume.json
}

resource "aws_iam_role_policy_attachment" "lambda_basic_execution" {
  role       = aws_iam_role.lambda.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy" "lambda_permissions" {
  name   = "${local.name_prefix}-lambda-permissions"
  role   = aws_iam_role.lambda.id
  policy = data.aws_iam_policy_document.lambda_permissions.json
}

# IAM: Glue job execution role

resource "aws_iam_role" "glue_job" {
  name               = "${local.name_prefix}-glue-job-role"
  assume_role_policy = data.aws_iam_policy_document.glue_assume.json
}

resource "aws_iam_role_policy_attachment" "glue_job_service_role" {
  role       = aws_iam_role.glue_job.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSGlueServiceRole"
}

resource "aws_iam_role_policy" "glue_job_permissions" {
  name   = "${local.name_prefix}-glue-job-permissions"
  role   = aws_iam_role.glue_job.id
  policy = data.aws_iam_policy_document.glue_job_permissions.json
}

# IAM: crawler role (assumed by the crawlers the Glue job creates/refreshes)

resource "aws_iam_role" "crawler" {
  name               = "${local.name_prefix}-crawler-role"
  assume_role_policy = data.aws_iam_policy_document.glue_assume.json
}

resource "aws_iam_role_policy_attachment" "crawler_service_role" {
  role       = aws_iam_role.crawler.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSGlueServiceRole"
}

resource "aws_iam_role_policy" "crawler_permissions" {
  name   = "${local.name_prefix}-crawler-permissions"
  role   = aws_iam_role.crawler.id
  policy = data.aws_iam_policy_document.crawler_permissions.json
}
