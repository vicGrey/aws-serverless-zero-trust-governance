package main

# Define the resource types that contain IAM policies
iam_policy_resources := {"aws_iam_role_policy", "aws_iam_policy"}

# Exclude platform-level policies that require wildcard * resources due to AWS API limits
is_excluded_policy(name) {
    name == "api_gateway_cloudwatch"
}
is_excluded_policy(name) {
    name == "config_lambda_policy"
}

# Helper to check if a field contains a wildcard (supports both single strings and lists)
has_wildcard(field) {
    is_string(field)
    field == "*"
}
has_wildcard(field) {
    is_array(field)
    field[_] == "*"
}

# Deny any IAM policy statement with wildcard (*) actions
deny[msg] {
    resource := input.resource_changes[_]
    iam_policy_resources[resource.type]
    not is_excluded_policy(resource.name)
    
    policy := json.unmarshal(resource.change.after.policy)
    statement := policy.Statement[_]
    has_wildcard(statement.Action)
    
    msg := sprintf("IAM policy '%s' contains wildcard (*) action — violates least privilege", [resource.name])
}

# Deny any IAM policy statement with wildcard (*) on resources
deny[msg] {
    resource := input.resource_changes[_]
    iam_policy_resources[resource.type]
    not is_excluded_policy(resource.name)
    
    policy := json.unmarshal(resource.change.after.policy)
    statement := policy.Statement[_]
    has_wildcard(statement.Resource)
    
    msg := sprintf("IAM policy '%s' contains wildcard (*) resource — violates least privilege", [resource.name])
}