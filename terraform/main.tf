terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = var.project_name
      Environment = var.environment
      ManagedBy   = "Terraform"
    }
  }
}

# Application Layer Modules
module "dynamodb" {
  source = "./modules/dynamodb"
}

module "cognito" {
  source = "./modules/cognito"
}

module "iam" {
  source = "./modules/iam"

  transactions_table_arn = module.dynamodb.transactions_table_arn
  cognito_user_pool_arn  = module.cognito.user_pool_arn
}

module "api_gateway" {
  source = "./modules/api_gateway"

  lambda_invoke_arn           = module.lambda.lambda_invoke_arn
  lambda_function_name        = module.lambda.lambda_function_name
  cognito_user_pool_arn       = module.cognito.user_pool_arn
  cognito_user_pool_client_id = module.cognito.user_pool_client_id
}

module "s3" {
  source = "./modules/s3"
}

module "lambda" {
  source = "./modules/lambda"

  transactions_table_arn      = module.dynamodb.transactions_table_arn
  transactions_table_name     = module.dynamodb.transactions_table_name
  lambda_execution_role_arn   = module.iam.lambda_execution_role_arn
  api_gateway_execution_arn   = module.api_gateway.execution_arn
}


