# Consumed by terraform/live/banking-data/terragrunt.hcl via extra_arguments
# (-var-file="${get_terragrunt_dir()}/../banking-data.tfvars"). Lives at the
# terraform/live/ level, not nested inside terraform/live/banking-data/, so
# every module's version-pin file sits in one place.
#
# lambda_s3_keys/glue_script_s3_keys/glue_common_s3_key are the last known-good
# build (banking-artifacts' build-release.yaml output) -- a real HCL pin
# instead of a bash ${VAR:-default} JSON string, so no shell escaping games.
# CI resolves these dynamically instead of reading this file's values (see
# main.yaml's "Resolve latest build artifact keys" step, which overwrites
# this file for the duration of that run); this is for local/manual runs.
project_name = "banking-data"

lambda_s3_keys = {
  event_handler = "lambda/sha256/0f7356ede4e73899120b84fb5f9ce2afd014bf2e3f93b1b9ac6532ee471b8bfd/lambda.zip"
}

glue_script_s3_keys = {
  etl = "glue/sha256/34c540b04174d238abc5f2f9810500088f1a139bc786bcadae7a2d0752bc9721/glue_script.py"
}

glue_common_s3_key = "glue/sha256/34c540b04174d238abc5f2f9810500088f1a139bc786bcadae7a2d0752bc9721/glue-common.zip"
