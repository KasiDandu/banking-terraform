variable "aws_region" {
  description = "AWS region to deploy into."
  type        = string
  default     = "us-east-2"
}

variable "assume_role_arn" {
  description = "IAM role to assume before provisioning, for cross-account environment promotion (e.g. a separate prod account). Null uses ambient credentials as-is."
  type        = string
  default     = null
}

variable "environment" {
  description = "Environment name (test, staging, prod)."
  type        = string
  default     = "test"
}

variable "project_name" {
  description = "Name prefix applied to all resources."
  type        = string
  default     = "banking-data"
}

variable "artifact_bucket" {
  description = "S3 bucket the build-release CI workflow publishes lambda.zip, glue_script.py, and glue-common.zip to."
  type        = string
}

# ---------------------------------------------------------------------------
# Generic resource factories -- shape documented in
# terraform/live/banking-data/{buckets,lambda,glue,eventbridge-rules}.json
# ---------------------------------------------------------------------------

variable "buckets" {
  description = "Bucket factory config: { with_terraform_buckets = { <logical_key> = { bucket_suffix = string } } }."
  type        = any
}

variable "lambda_functions" {
  description = "Lambda factory config, keyed by logical function name. See lambda.json."
  type        = any
}

variable "glue_jobs" {
  description = "Glue job factory config, keyed by logical job name. See glue.json."
  type        = any
}

variable "eventbridge_rules" {
  description = "List of EventBridge rule definitions. See eventbridge-rules.json."
  type        = any
}

# ---------------------------------------------------------------------------
# Per-build artifact locations -- change every release, kept separate from
# the structural config above. CI resolves these dynamically; environments/
# *.env pins a fallback snapshot for local/manual runs.
# ---------------------------------------------------------------------------

variable "lambda_s3_keys" {
  description = "Map of lambda logical name -> its code's S3 key within artifact_bucket."
  type        = map(string)
}

variable "glue_script_s3_keys" {
  description = "Map of glue job logical name -> its script's S3 key within artifact_bucket."
  type        = map(string)
}

variable "glue_common_s3_key" {
  description = "Key of glue-common.zip within artifact_bucket, shared --extra-py-files for every Glue job."
  type        = string
}

variable "glue_database_name" {
  description = "Fixed Glue Catalog database shared by per-source tables and the audit_lineage table."
  type        = string
  default     = "banking_data"
}

variable "raw_key_prefix" {
  description = "Key prefix under the landing bucket that source objects land in, e.g. raw/<source_name>/<file>. Single source of truth for both the event_handler Lambda's RAW_KEY_PREFIX env var and the EventBridge S3-trigger rule's key filter."
  type        = string
  default     = "raw/"
}

variable "config_key_prefix" {
  description = "Key prefix under the config bucket that per-source config JSON files live at."
  type        = string
  default     = "config/"
}
