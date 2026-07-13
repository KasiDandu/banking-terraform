# Shared Terragrunt config included by every live/<env>/terragrunt.hcl.
# Backend bucket/key/region/lock-table come from each environment's env.hcl,
# so this one block is the single source of truth for remote state across
# environments -- no copy-pasted backend config per environment.

locals {
  env_vars = read_terragrunt_config("${get_terragrunt_dir()}/env.hcl")
}

remote_state {
  backend = "s3"
  generate = {
    path      = "backend.tf"
    if_exists = "overwrite"
  }
  config = {
    bucket         = local.env_vars.locals.backend_bucket
    key            = local.env_vars.locals.backend_key
    region         = local.env_vars.locals.aws_region
    dynamodb_table = local.env_vars.locals.lock_table
    encrypt        = true

    # kvrd-artifacts is a shared bucket (also used for CI build artifacts) --
    # don't let Terragrunt "fix" its versioning/encryption/ACL settings.
    disable_bucket_update = true
  }
}
