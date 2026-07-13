locals {
  environment = "prod"

  # --- PLACEHOLDER: no prod AWS account exists yet ---
  # Every value below deliberately points at something that doesn't exist,
  # so `terragrunt plan`/`apply` here fails loudly (AssumeRole/NoSuchBucket)
  # instead of silently landing in the test account. Fill these in for real
  # once a prod account is provisioned:
  #   1. aws_account_id  -> the real prod account ID
  #   2. assume_role_arn -> a role in that account this CI identity can assume
  #   3. backend_bucket / lock_table / artifact_bucket -> prod's own S3
  #      state bucket, DynamoDB lock table, and CI artifact bucket
  #      (bootstrap the same way test's were: create the bucket + table,
  #      `terraform import` the lock table -- see README.md)
  aws_account_id  = "000000000000"
  assume_role_arn = "arn:aws:iam::000000000000:role/banking-terraform-deploy"

  aws_region      = "us-east-1"
  backend_bucket  = "REPLACE_ME-banking-data-prod-tfstate"
  backend_key     = "banking-terraform/prod/state.tfstate"
  lock_table      = "banking-data-prod-tfstate-lock"
  artifact_bucket = "REPLACE_ME-banking-data-prod-artifacts"

  lambda_s3_key      = "REPLACE_ME"
  glue_script_s3_key = "REPLACE_ME"
  glue_common_s3_key = "REPLACE_ME"
}
