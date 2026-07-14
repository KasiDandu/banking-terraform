# Sibling unit to ../buckets and ../banking-data. Creates the IAM roles
# (trust policy + baseline managed policy) that ../banking-data attaches its
# own service-specific policies to via a `dependency` block below.

remote_state {
  backend = "s3"
  generate = {
    path      = "backend.tf"
    if_exists = "overwrite"
  }
  config = {
    bucket                = get_env("BACKEND_BUCKET")
    key                   = "${get_env("PREFIX_KEY")}/iam/terraform.tfstate"
    region                = get_env("AWS_REGION")
    dynamodb_table        = get_env("LOCK_TABLE")
    encrypt               = true
    disable_bucket_update = true
  }
}

terraform {
  source = "../../modules/iam"
}
