# Package the Lambda function
data "archive_file" "lambda_zip" {
  type        = "zip"
  source_file = "${path.module}/../../../lambda/transaction_api/app.py"
  output_path = "${path.module}/transaction_api.zip"
}

resource "aws_lambda_function" "transaction_api" {
  function_name    = "${var.project_name}-transaction-api"
  role             = var.lambda_execution_role_arn
  handler          = "app.lambda_handler"
  runtime          = "python3.12"
  filename         = data.archive_file.lambda_zip.output_path
  source_code_hash = data.archive_file.lambda_zip.output_base64sha256

  environment {
    variables = {
      TRANSACTIONS_TABLE = var.transactions_table_name
    }
  }

  timeout     = 30
  memory_size = 256

  tracing_config {
    mode = "Active"
  }

  tags = {
    Name = "Transaction API Lambda"
  }
}
