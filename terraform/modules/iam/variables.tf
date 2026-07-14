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
