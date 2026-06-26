variable "project_name" {
  description = "Project name for resource naming"
  type        = string
  default     = "zero-trust-serverless"
}

variable "transactions_table_arn" {
  description = "ARN of the DynamoDB transactions table"
  type        = string
}

variable "cognito_user_pool_arn" {
  description = "ARN of the Cognito User Pool"
  type        = string
}