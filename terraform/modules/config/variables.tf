variable "project_name" {
  description = "Project name for resource naming"
  type        = string
  default     = "zero-trust-serverless"
}

variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}