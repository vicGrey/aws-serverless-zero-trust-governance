output "bucket_id" {
  description = "S3 bucket ID"
  value       = aws_s3_bucket.audit_logs.id
}

output "bucket_arn" {
  description = "S3 bucket ARN"
  value       = aws_s3_bucket.audit_logs.arn
}