package main

# Deny API Gateway methods without Cognito authorizer
deny[msg] {
    resource := input.resource_changes[_]
    resource.type == "aws_api_gateway_method"
    
    resource.change.after.authorization == "NONE"
    
    msg := sprintf("API Gateway method '%s' has no authorizer — unauthenticated endpoint", [resource.name])
}

# Deny API Gateway methods with AWS_IAM instead of Cognito (must be COGNITO_USER_POOLS)
deny[msg] {
    resource := input.resource_changes[_]
    resource.type == "aws_api_gateway_method"
    
    resource.change.after.authorization == "AWS_IAM"
    
    msg := sprintf("API Gateway method '%s' uses AWS_IAM instead of COGNITO_USER_POOLS", [resource.name])
}

# Ensure API Gateway methods have an authorizer_id when using COGNITO_USER_POOLS
deny[msg] {
    resource := input.resource_changes[_]
    resource.type == "aws_api_gateway_method"
    
    resource.change.after.authorization == "COGNITO_USER_POOLS"
    not resource.change.after.authorizer_id
    
    msg := sprintf("API Gateway method '%s' missing authorizer_id", [resource.name])
}