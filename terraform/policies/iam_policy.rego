package main

# Deny any IAM policy statement with wildcard (*) actions
deny[msg] {
    resource := input.resource_changes[_]
    resource.type == "aws_iam_role_policy"
    
    policy := json.unmarshal(resource.change.after.policy)
    statement := policy.Statement[_]
    action := statement.Action[_]
    action == "*"
    
    msg := sprintf("IAM policy '%s' contains wildcard (*) action — violates least privilege", [resource.name])
}

# Deny any IAM policy statement with wildcard (*) on resources
deny[msg] {
    resource := input.resource_changes[_]
    resource.type == "aws_iam_role_policy"
    
    policy := json.unmarshal(resource.change.after.policy)
    statement := policy.Statement[_]
    resource_field := statement.Resource[_]
    resource_field == "*"
    
    msg := sprintf("IAM policy '%s' contains wildcard (*) resource — violates least privilege", [resource.name])
}