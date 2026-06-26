variable "project_name" {
  description = "Project name for resource naming"
  type        = string
  default     = "zero-trust-serverless"
}

variable "transactions_table_arn" {
  description = "ARN of the DynamoDB transactions table"
  type        = string
}

variable "transactions_table_name" {
  description = "Name of the DynamoDB transactions table"
  type        = string
}

variable "lambda_execution_role_arn" {
  description = "ARN of the Lambda execution IAM role"
  type        = string
}

variable "api_gateway_execution_arn" {
  description = "Execution ARN of the API Gateway"
  type        = string
  default     = ""
}