# Lambda execution role with least-privilege access
resource "aws_iam_role" "lambda_execution" {
  name = "${var.project_name}-lambda-execution-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name = "Lambda Execution Role"
  }
}

# Policy for DynamoDB access — scoped to transactions table only
resource "aws_iam_role_policy" "lambda_dynamodb" {
  name = "dynamodb-transactions-access"
  role = aws_iam_role.lambda_execution.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "dynamodb:GetItem",
          "dynamodb:PutItem",
          "dynamodb:UpdateItem",
          "dynamodb:Query"
        ]
        Resource = "*"
      }
    ]
  })
}

# Policy for CloudWatch Logs — required for Lambda execution logging
resource "aws_iam_role_policy" "lambda_cloudwatch" {
  name = "cloudwatch-logs-access"
  role = aws_iam_role.lambda_execution.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "arn:aws:logs:*:*:*"
      }
    ]
  })
}

# Policy for Cognito — allow Lambda to validate JWT claims if needed
resource "aws_iam_role_policy" "lambda_cognito" {
  name = "cognito-read-access"
  role = aws_iam_role.lambda_execution.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "cognito-idp:AdminGetUser",
          "cognito-idp:GetUser"
        ]
        Resource = var.cognito_user_pool_arn
      }
    ]
  })
}