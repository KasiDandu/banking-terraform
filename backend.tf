terraform {
  # Bucket/key/region/dynamodb_table are supplied at init time via
  # -backend-config (see Makefile), so this repo works across environments
  # without editing committed files. dynamodb_table enables state locking,
  # so concurrent applies fail fast on a lock conflict instead of racing.
  backend "s3" {}
}
