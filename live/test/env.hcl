locals {
  environment     = "test"
  aws_region      = "us-east-1"
  backend_bucket  = "kvrd-artifacts"
  backend_key     = "banking-terraform/test/state.tfstate"
  lock_table      = "banking-data-test-tfstate-lock"
  artifact_bucket = "kvrd-artifacts"

  # Matches build-release.yaml's build job output for banking-artifacts.
  # The GitHub Actions workflows resolve these dynamically at run time
  # (see terraform-plan.yaml's "Resolve latest build artifact keys" step);
  # this is a pinned snapshot for local/manual terragrunt runs and should be
  # refreshed to match whatever was last actually deployed.
  lambda_s3_key      = "lambda/sha256/e5ac6bf677df20ad00996a99e40dd1dcd96d25fd73abe65d1a4ffbed813e44d2/lambda.zip"
  glue_script_s3_key = "glue/sha256/940a86350107df97707ec9086ec86313c7e4c55dea0ae37b6d400f0da356c2b4/glue_script.py"
  glue_common_s3_key = "glue/sha256/0a968279d3792750c2a59f610399d8fb47354485769f97f7a697aeea9b1b961a/glue-common.zip"
}
