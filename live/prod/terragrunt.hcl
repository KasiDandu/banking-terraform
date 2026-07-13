include "root" {
  path = find_in_parent_folders()
}

locals {
  env_vars = read_terragrunt_config("env.hcl")
}

terraform {
  source = "../.."
}

inputs = {
  environment        = local.env_vars.locals.environment
  aws_region         = local.env_vars.locals.aws_region
  assume_role_arn    = local.env_vars.locals.assume_role_arn
  artifact_bucket    = local.env_vars.locals.artifact_bucket
  lambda_s3_key      = local.env_vars.locals.lambda_s3_key
  glue_script_s3_key = local.env_vars.locals.glue_script_s3_key
  glue_common_s3_key = local.env_vars.locals.glue_common_s3_key
}
