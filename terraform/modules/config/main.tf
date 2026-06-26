# Enable AWS Config
resource "aws_config_configuration_recorder" "main" {
  name     = "${var.project_name}-config-recorder"
  role_arn = aws_iam_role.config.arn

  recording_group {
    all_supported = true
  }
}

# IAM role for AWS Config
resource "aws_iam_role" "config" {
  name = "${var.project_name}-config-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "config.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "config" {
  role       = aws_iam_role.config.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWS_ConfigRole"
}

# S3 bucket for Config delivery
resource "aws_s3_bucket" "config" {
  bucket = "${var.project_name}-config-${random_string.config_suffix.result}"

  tags = {
    Name = "Config Delivery Bucket"
  }
}

resource "random_string" "config_suffix" {
  length  = 8
  special = false
  upper   = false
}

resource "aws_s3_bucket_public_access_block" "config" {
  bucket = aws_s3_bucket.config.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_policy" "config" {
  bucket = aws_s3_bucket.config.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AWSConfigBucketPermissions"
        Effect = "Allow"
        Principal = {
          Service = "config.amazonaws.com"
        }
        Action   = "s3:GetBucketAcl"
        Resource = aws_s3_bucket.config.arn
      },
      {
        Sid    = "AWSConfigBucketDelivery"
        Effect = "Allow"
        Principal = {
          Service = "config.amazonaws.com"
        }
        Action   = "s3:PutObject"
        Resource = "${aws_s3_bucket.config.arn}/*"
        Condition = {
          StringEquals = {
            "s3:x-amz-acl" = "bucket-owner-full-control"
          }
        }
      }
    ]
  })
}

resource "aws_config_delivery_channel" "main" {
  name           = "${var.project_name}-delivery-channel"
  s3_bucket_name = aws_s3_bucket.config.id

  depends_on = [aws_s3_bucket_policy.config, aws_config_configuration_recorder.main]
}

resource "aws_config_configuration_recorder_status" "main" {
  name       = aws_config_configuration_recorder.main.name
  is_enabled = true

  depends_on = [aws_config_delivery_channel.main]
}

# Managed Rules — aligned with the four misconfiguration scenarios

# 1. IAM: Detect policies with full administrative privileges
resource "aws_config_config_rule" "iam_policy_no_statements_with_admin_access" {
  name = "iam-policy-no-statements-with-admin-access"

  source {
    owner             = "AWS"
    source_identifier = "IAM_POLICY_NO_STATEMENTS_WITH_ADMIN_ACCESS"
  }

  depends_on = [aws_config_configuration_recorder.main]
}

# 2. S3: Detect public read access
resource "aws_config_config_rule" "s3_bucket_public_read_prohibited" {
  name = "s3-bucket-public-read-prohibited"

  source {
    owner             = "AWS"
    source_identifier = "S3_BUCKET_PUBLIC_READ_PROHIBITED"
  }

  depends_on = [aws_config_configuration_recorder.main]
}

# Data source to package the custom rule Lambda
data "archive_file" "config_lambda_zip" {
  type        = "zip"
  source_file = "${path.module}/custom_rule_lambda/lambda_function.py"
  output_path = "${path.module}/custom_rule_lambda.zip"
}

# IAM role for custom Config rule Lambda
resource "aws_iam_role" "config_lambda_role" {
  name = "${var.project_name}-config-lambda-role"

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
}

resource "aws_iam_role_policy_attachment" "config_lambda_basic" {
  role       = aws_iam_role.config_lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy" "config_lambda_policy" {
  name = "config-eval-policy"
  role = aws_iam_role.config_lambda_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "config:PutEvaluations",
          "apigateway:GET"
        ]
        Resource = "*"
      }
    ]
  })
}

# Lambda function for custom Config rule evaluation
resource "aws_lambda_function" "config_auth_validator" {
  function_name    = "${var.project_name}-config-auth-validator"
  role             = aws_iam_role.config_lambda_role.arn
  handler          = "lambda_function.lambda_handler"
  runtime          = "python3.12"
  filename         = data.archive_file.config_lambda_zip.output_path
  source_code_hash = data.archive_file.config_lambda_zip.output_base64sha256
  timeout          = 60
}

# Grant permission to Config service to invoke this Lambda
resource "aws_lambda_permission" "config_auth_validator" {
  statement_id  = "AllowExecutionFromConfig"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.config_auth_validator.function_name
  principal     = "config.amazonaws.com"
}

# 3. API Gateway: Detect unauthenticated endpoints (Custom Rule)
resource "aws_config_config_rule" "api_gw_auth_check" {
  name        = "api-gw-auth-check"
  description = "Verifies that API Gateway endpoints enforce Cognito authentication."

  source {
    owner             = "CUSTOM_LAMBDA"
    source_identifier = aws_lambda_function.config_auth_validator.arn
    source_detail {
      message_type = "ConfigurationItemChangeNotification"
    }
  }

  depends_on = [aws_config_configuration_recorder.main, aws_lambda_permission.config_auth_validator]
}

# 4. API Gateway & Lambda: Detect disabled execution logging (Scenario 4)
resource "aws_config_config_rule" "api_gw_execution_logging_enabled" {
  name        = "api-gw-execution-logging-enabled"
  description = "Verifies that execution logging is enabled for API Gateway stages."

  source {
    owner             = "AWS"
    source_identifier = "API_GW_EXECUTION_LOGGING_ENABLED"
  }

  input_parameters = jsonencode({
    loggingLevel = "INFO"
  })

  depends_on = [aws_config_configuration_recorder.main]
}

# Security Hub — commented out due to subscription requirement
# resource "aws_securityhub_account" "main" {
#   enable_default_standards = true
# }

# resource "aws_securityhub_product_subscription" "config" {
#   product_arn = "arn:aws:securityhub:${var.aws_region}::product/aws/config"
#   depends_on  = [aws_securityhub_account.main]
# }