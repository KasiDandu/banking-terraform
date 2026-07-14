# Sibling unit to ../iam and ../banking-data -- each has its own state file
# (PREFIX_KEY is a directory-like prefix; every unit appends its own
# filename) but shares the same backend bucket/lock table. Account/region
# come from shell env vars sourced from environments/<env>.env by
# deploys/Makefile before terragrunt runs.

remote_state {
  backend = "s3"
  generate = {
    path      = "backend.tf"
    if_exists = "overwrite"
  }
  config = {
    bucket         = get_env("BACKEND_BUCKET")
    key            = "${get_env("PREFIX_KEY")}/buckets/terraform.tfstate"
    region         = get_env("AWS_REGION")
    dynamodb_table = get_env("LOCK_TABLE")
    encrypt        = true

    # kvrd-artifacts (test's backend bucket) is shared with CI build
    # artifacts -- don't let Terragrunt "fix" its versioning/encryption/ACLs.
    disable_bucket_update = true
  }
}

terraform {
  source = "../../modules/buckets"
}

inputs = {
  buckets = jsondecode(file("buckets.json"))
}
