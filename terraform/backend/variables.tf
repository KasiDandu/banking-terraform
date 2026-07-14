variable "project_name" {
  description = "Name prefix applied to the bucket/table."
  type        = string
  default     = "banking-data"
}

variable "environment" {
  description = "Environment name this backend is being bootstrapped for (e.g. prod)."
  type        = string
}

variable "aws_region" {
  description = "AWS region to create the state bucket and lock table in."
  type        = string
  default     = "us-east-1"
}

variable "state_bucket_name" {
  description = "Globally-unique S3 bucket name for this environment's Terraform state."
  type        = string
}
