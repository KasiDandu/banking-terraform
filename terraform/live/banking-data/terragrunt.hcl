# Sibling unit to ../buckets and ../iam. Bucket names are looked up via SSM
# at the module level (not a Terragrunt dependency) -- but this unit still
# needs buckets to exist first, hence `dependencies` (ordering only, no
# outputs consumed) rather than skipping the relationship entirely. IAM role
# names/ARNs *are* consumed via a `dependency` block, since this unit
# attaches its own policies to roles the iam unit creates.

dependencies {
  paths = ["../buckets"]
}

dependency "iam" {
  config_path = "../iam"

  # Only "validate" gets mocks (so this unit's HCL can be sanity-checked
  # before iam has ever been applied) -- deliberately NOT "plan". A `plan`
  # that gets saved and applied later must always be computed from the
  # iam unit's *real* outputs: `terraform apply <planfile>` re-executes
  # exactly what was planned, mock values baked in and all, ignoring
  # fresher env vars at apply time. A mocked plan silently trying to
  # attach policies to a role named "mock-glue-job-role" is exactly that
  # failure mode. Apply ../iam for real before planning this unit.
  mock_outputs = {
    lambda_role_name   = "mock-lambda-role"
    lambda_role_arn    = "arn:aws:iam::000000000000:role/mock-lambda-role"
    glue_job_role_name = "mock-glue-job-role"
    glue_job_role_arn  = "arn:aws:iam::000000000000:role/mock-glue-job-role"
    crawler_role_name  = "mock-crawler-role"
    crawler_role_arn   = "arn:aws:iam::000000000000:role/mock-crawler-role"
  }
  mock_outputs_allowed_terraform_commands = ["validate"]
}

remote_state {
  backend = "s3"
  generate = {
    path      = "backend.tf"
    if_exists = "overwrite"
  }
  config = {
    bucket         = get_env("BACKEND_BUCKET")
    key            = "${get_env("PREFIX_KEY")}/banking-data/terraform.tfstate"
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

  # Lives one level up (terraform/live/banking-data.tfvars), not nested in
  # this module's own directory -- every module's version-pin file sits in
  # one place at the terraform/live/ level.
  extra_arguments "var_files" {
    commands  = ["plan", "apply", "destroy", "import", "refresh", "validate"]
    arguments = ["-var-file=${get_terragrunt_dir()}/../banking-data.tfvars"]
  }
}

locals {
  glue_vars        = jsondecode(file("glue.json"))
  lambda_vars      = jsondecode(file("lambda.json"))
  eventbridge_vars = jsondecode(file("eventbridge-rules.json"))
}

inputs = {
  glue_jobs         = local.glue_vars
  lambda_functions  = local.lambda_vars
  eventbridge_rules = local.eventbridge_vars

  lambda_role_name   = dependency.iam.outputs.lambda_role_name
  lambda_role_arn    = dependency.iam.outputs.lambda_role_arn
  glue_job_role_name = dependency.iam.outputs.glue_job_role_name
  glue_job_role_arn  = dependency.iam.outputs.glue_job_role_arn
  crawler_role_name  = dependency.iam.outputs.crawler_role_name
  crawler_role_arn   = dependency.iam.outputs.crawler_role_arn
}
