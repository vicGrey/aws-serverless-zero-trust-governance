variable "aws_region" {
  description = "AWS region for deployment"
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Project name for resource tagging"
  type        = string
  default     = "zero-trust-serverless"
}

variable "environment" {
  description = "Deployment environment"
  type        = string
  default     = "dev"
}