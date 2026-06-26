output "config_recorder_name" {
  description = "AWS Config recorder name"
  value       = aws_config_configuration_recorder.main.name
}

output "security_hub_enabled" {
  description = "Security Hub enabled status"
  value       = aws_securityhub_account.main.id
}