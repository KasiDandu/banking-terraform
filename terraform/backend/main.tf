# Bootstraps a NEW environment's remote state backend: the S3 bucket
# Terraform/Terragrunt store state in, and the DynamoDB table used for state
# locking. Deliberately uses local state -- this creates the very things a
# remote backend needs, so it can't depend on one itself.
#
# Not needed for the existing `test` environment: its state already lives in
# the pre-existing `kvrd-artifacts` bucket (shared with CI build artifacts),
# and its lock table was already bootstrapped once via the AWS CLI (see the
# root README's "State locking" section). Run this for any *new* environment
# (e.g. once a real prod account exists) instead of repeating that manual
# dance.
#
# Usage:
#   cd terraform/backend
#   terraform init
#   terraform apply -var="environment=prod" -var="state_bucket_name=<globally-unique-name>"

terraform {
  required_version = ">= 1.5"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

resource "aws_s3_bucket" "tfstate" {
  bucket = var.state_bucket_name
  tags   = { Name = "${var.project_name}-${var.environment}-tfstate" }
}

resource "aws_s3_bucket_versioning" "tfstate" {
  bucket = aws_s3_bucket.tfstate.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "tfstate" {
  bucket = aws_s3_bucket.tfstate.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "tfstate" {
  bucket                  = aws_s3_bucket.tfstate.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_dynamodb_table" "tfstate_lock" {
  name         = "${var.project_name}-${var.environment}-tfstate-lock"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }

  tags = { Name = "${var.project_name}-${var.environment}-tfstate-lock" }
}
