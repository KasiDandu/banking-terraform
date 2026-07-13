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
