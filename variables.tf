variable "aws_region" {
  description = "AWS region to deploy into."
  type        = string
  default     = "us-east-2"
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

variable "lambda_s3_key" {
  description = "Key of lambda.zip within artifact_bucket, e.g. lambda/sha256/<hash>/lambda.zip or lambda/<version>/lambda.zip."
  type        = string
}

variable "glue_script_s3_key" {
  description = "Key of glue_script.py within artifact_bucket."
  type        = string
}

variable "glue_common_s3_key" {
  description = "Key of glue-common.zip within artifact_bucket."
  type        = string
}

variable "glue_database_name" {
  description = "Fixed Glue Catalog database shared by per-source tables and the audit_lineage table."
  type        = string
  default     = "banking_data"
}

variable "raw_key_prefix" {
  description = "Key prefix under the raw bucket that source objects land in, e.g. raw/<source_name>/<file>."
  type        = string
  default     = "raw/"
}

variable "config_key_prefix" {
  description = "Key prefix under the config bucket that per-source config JSON files live at."
  type        = string
  default     = "config/"
}

variable "lambda_runtime" {
  description = "Lambda runtime for the EventBridge handler."
  type        = string
  default     = "python3.12"
}

variable "glue_version" {
  description = "Glue version for the ETL job."
  type        = string
  default     = "4.0"
}

variable "glue_worker_type" {
  description = "Glue worker type."
  type        = string
  default     = "G.1X"
}

variable "glue_number_of_workers" {
  description = "Number of Glue workers."
  type        = number
  default     = 2
}

variable "glue_timeout_minutes" {
  description = "Glue job timeout in minutes."
  type        = number
  default     = 60
}
