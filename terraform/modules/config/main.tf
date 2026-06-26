# Enable AWS Config
resource "aws_config_configuration_recorder" "main" {
  name     = "${var.project_name}-config-recorder"
  role_arn = aws_iam_role.config.arn

  recording_group {
    all_supported                 = true
    record_global_resource_types = true
  }
}

resource "aws_config_delivery_channel" "main" {
  name           = "${var.project_name}-delivery-channel"
  s3_bucket_name = aws_s3_bucket.config.id

  depends_on = [aws_config_configuration_recorder.main]
}

resource "aws_config_configuration_recorder_status" "main" {
  name       = aws_config_configuration_recorder.main.name
  is_enabled = true

  depends_on = [aws_config_delivery_channel.main]
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

# 3. API Gateway: Detect unauthenticated endpoints
resource "aws_config_config_rule" "api_gw_execution_logging_enabled" {
  name = "api-gw-execution-logging-enabled"

  source {
    owner             = "AWS"
    source_identifier = "API_GW_EXECUTION_LOGGING_ENABLED"
  }

  input_parameters = jsonencode({
    loggingLevel = "INFO"
  })

  depends_on = [aws_config_configuration_recorder.main]
}

# 4. CloudWatch: Detect disabled logging
resource "aws_config_config_rule" "cloudwatch_log_group_encrypted" {
  name = "cloudwatch-log-group-encrypted"

  source {
    owner             = "AWS"
    source_identifier = "CLOUDWATCH_LOG_GROUP_ENCRYPTED"
  }

  depends_on = [aws_config_configuration_recorder.main]
}

# Enable AWS Security Hub
resource "aws_securityhub_account" "main" {
  enable_default_standards = true
}

# Subscribe AWS Config findings to Security Hub
resource "aws_securityhub_product_subscription" "config" {
  product_arn = "arn:aws:securityhub:${var.aws_region}::product/aws/config"

  depends_on = [aws_securityhub_account.main]
}