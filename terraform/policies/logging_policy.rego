package main

# Deny API Gateway stages without CloudWatch logging
deny[msg] {
    resource := input.resource_changes[_]
    resource.type == "aws_api_gateway_stage"
    
    not resource.change.after.access_log_settings
    
    msg := sprintf("API Gateway stage '%s' missing CloudWatch access_log_settings", [resource.name])
}

# Deny Lambda functions without active X-Ray tracing
deny[msg] {
    resource := input.resource_changes[_]
    resource.type == "aws_lambda_function"
    
    not resource.change.after.tracing_config
    
    msg := sprintf("Lambda function '%s' missing X-Ray tracing_config", [resource.name])
}

# Deny Lambda functions with PassThrough tracing instead of Active
deny[msg] {
    resource := input.resource_changes[_]
    resource.type == "aws_lambda_function"
    
    resource.change.after.tracing_config.mode == "PassThrough"
    
    msg := sprintf("Lambda function '%s' has PassThrough tracing — must be Active", [resource.name])
}