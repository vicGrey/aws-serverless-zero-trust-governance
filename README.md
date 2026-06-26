# AWS Serverless Zero Trust Governance Framework

A Zero Trust and Policy-as-Code governance framework for AWS serverless financial applications.

## Architecture

- **Application Layer**: AWS Lambda (Python 3.12), API Gateway, DynamoDB, Amazon Cognito
- **Pre-Deployment Governance**: Terraform + Open Policy Agent (OPA) + Conftest + GitHub Actions
- **Runtime Compliance**: AWS Config + AWS Security Hub

## Project Structure
terraform/          # Infrastructure-as-Code definitions
lambda/             # Serverless application code
.github/workflows/  # CI/CD pipeline definitions

## Author

OKOROAFOR, Victor — Federal University of Technology, Minna
