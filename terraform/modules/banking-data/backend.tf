terraform {
  # Bucket/key/region/dynamodb_table are supplied at init time -- via
  # Terragrunt's remote_state.generate (see terraform/live/banking-data) when
  # run through Terragrunt, or via -backend-config otherwise -- so this
  # module works across environments without editing committed files.
  # dynamodb_table enables state locking, so concurrent applies fail fast on
  # a lock conflict instead of racing.
  backend "s3" {}
}
