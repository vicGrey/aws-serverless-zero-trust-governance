output "transactions_table_name" {
  description = "Name of the DynamoDB transactions table"
  value       = aws_dynamodb_table.transactions.name
}

output "transactions_table_arn" {
  description = "ARN of the DynamoDB transactions table"
  value       = aws_dynamodb_table.transactions.arn
}