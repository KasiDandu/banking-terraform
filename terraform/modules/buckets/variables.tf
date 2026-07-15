variable "aws_region" {
  description = "AWS region to deploy into."
  type        = string
  default     = "us-east-2"
}

variable "assume_role_arn" {
  description = "IAM role to assume before provisioning, for cross-account environment promotion. Null uses ambient credentials as-is."
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

variable "buckets" {
  description = "Bucket factory config: { with_terraform_buckets = { <logical_key> = { bucket_suffix = string } } }. See terraform/live/banking-data/buckets/buckets.json."
  type        = any
}

variable "eventbridge_bucket_key" {
  description = "Logical bucket key (from var.buckets) to enable native S3 -> EventBridge \"Object Created\" notifications on. Null disables it."
  type        = string
  default     = "landing"
}

variable "force_destroy" {
  description = "Allow `terraform destroy` to delete these buckets even if they still contain objects. Leave false (safe) for any environment holding real data -- only test/ephemeral environments should set this true, or a destroy silently fails partway through (BucketNotEmpty) after already tearing down banking-data/iam, leaving an inconsistent state."
  type        = bool
  default     = false
}
