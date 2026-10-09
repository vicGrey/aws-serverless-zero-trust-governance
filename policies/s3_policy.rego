package main

# Deny S3 buckets without public access block configured
deny[msg] {
    resource := input.resource_changes[_]
    resource.type == "aws_s3_bucket"
    
    # Check if there's a corresponding public_access_block resource
    not s3_public_access_block_exists(resource.change.after.bucket)
    
    msg := sprintf("S3 bucket '%s' missing aws_s3_bucket_public_access_block — public exposure risk", [resource.name])
}

s3_public_access_block_exists(bucket_name) {
    resource := input.resource_changes[_]
    resource.type == "aws_s3_bucket_public_access_block"
    resource.change.after.bucket == bucket_name
}

# Deny S3 buckets with public access block disabled
deny[msg] {
    resource := input.resource_changes[_]
    resource.type == "aws_s3_bucket_public_access_block"
    
    resource.change.after.block_public_acls != true
    resource.change.after.block_public_policy != true
    resource.change.after.ignore_public_acls != true
    resource.change.after.restrict_public_buckets != true
    
    msg := sprintf("S3 bucket '%s' public access block not fully restricted", [resource.change.after.bucket])
}