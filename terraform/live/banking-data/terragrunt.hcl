# Single live stack, reused across environments -- account/region/state
# location come from shell env vars (BACKEND_BUCKET/PREFIX_KEY/AWS_REGION/
# LOCK_TABLE, plus TF_VAR_environment/assume_role_arn/artifact_bucket/
# *_s3_key) sourced from environments/<env>.env by deploys/Makefile before
# terragrunt runs. Only the resource-tuning knobs that DON'T vary by account
# live here, split by AWS service to match terraform/modules/banking-data's
# file layout.

locals {
  glue_vars        = jsondecode(file("glue.json"))
  lambda_vars      = jsondecode(file("lambda.json"))
  buckets_vars     = jsondecode(file("buckets.json"))
  eventbridge_vars = jsondecode(file("eventbridge-rules.json"))
}

remote_state {
  backend = "s3"
  generate = {
    path      = "backend.tf"
    if_exists = "overwrite"
  }
  config = {
    bucket         = get_env("BACKEND_BUCKET")
    key            = get_env("PREFIX_KEY")
    region         = get_env("AWS_REGION")
    dynamodb_table = get_env("LOCK_TABLE")
    encrypt        = true

    # kvrd-artifacts (test's backend bucket) is shared with CI build
    # artifacts -- don't let Terragrunt "fix" its versioning/encryption/ACLs.
    disable_bucket_update = true
  }
}

terraform {
  source = "../../modules/banking-data"

  extra_arguments "var_files" {
    commands  = ["plan", "apply", "destroy", "import", "refresh", "validate"]
    arguments = ["-var-file=${get_terragrunt_dir()}/banking-data.tfvars"]
  }
}

inputs = merge(
  local.glue_vars,
  local.lambda_vars,
  local.buckets_vars,
  local.eventbridge_vars,
)
