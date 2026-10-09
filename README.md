aws-serverless-zero-trust-governance
A Zero Trust governance framework for AWS serverless financial applications. It blocks misconfigured infrastructure before deployment and detects configuration drift after.

Built for my undergraduate project at the Federal University of Technology, Minna. The framework was designed, implemented, and tested against four misconfiguration scenarios. Results and limitations are documented below.

The problem
Serverless applications shift infrastructure configuration onto developers. Every Lambda function needs an IAM execution role, every API endpoint needs an authorizer, every S3 bucket needs a public access block. Get one of those wrong and the deployment still succeeds. Nothing fails. The misconfiguration just sits there until someone finds it.

Most tooling approaches this reactively. Scanners identify problems after deployment, and runtime monitors flag drift on a schedule. Both leave a window between the misconfiguration existing and anyone knowing about it.

This framework closes the window at the earliest point it can: the pull request.

Architecture
Three layers.

Pre-deployment governance. Terraform defines the infrastructure. On every push, GitHub Actions runs terraform plan, converts the plan to JSON, and evaluates it against Rego policies with OPA and Conftest. A violation exits non-zero, the step fails, and the apply job never runs. Terraform never reaches the AWS API.

Application. The serverless financial API itself. AWS Lambda for transaction logic, API Gateway for routing and JWT validation, DynamoDB for state, Cognito for identity.

Runtime compliance. AWS Config managed rules evaluate deployed resources against a baseline. A manual change made outside the pipeline is detected and flagged through CloudWatch alerts.

How a deployment flows
text
commit to main
     |
     v
GitHub Actions: checkout, install, syntax check
     |
     v
terraform plan -> tfplan
     |
     v
terraform show -json -> tfplan.json
     |
     v
conftest test tfplan.json --policy ./policies/
     |
     +-- fail --> pipeline stops. apply job never runs.
     |
     v
terraform apply (separate job, needs: validate)
The gate adds about 7.3 seconds to a pipeline run.

Misconfiguration scenarios
The policy library covers four scenarios:

Scenario	What it catches	Rule
Over-privileged IAM roles	"Action": "*" or "Resource": "*" in a policy document	Rego
Publicly exposed S3 buckets	Public access block disabled	Rego + AWS Config
Unauthenticated API endpoints	API Gateway method with no authorizer	Rego + custom Config rule
Disabled execution logging	API Gateway stage with no logging	Rego + AWS Config
Each scenario has a corresponding rule at the pre-deployment layer and, where applicable, at the runtime layer.

Results
Tested against the four scenarios above.

Metric	Result
Enforcement success rate	100%
Detection accuracy	100%
False positive rate	0%
Enforcement latency	7.3 s
Runtime detection latency	3 min 30 s
API latency overhead	~46 ms
Four scenarios is a small sample. Read this as evidence the approach works, not as a detection rate.

What this doesn't catch
Service-level wildcards. The rule matches a bare "*". A permission like "s3:*" is not caught and would need pattern matching rather than an exact string comparison.

Changes made outside the pipeline. A resource created or modified directly in the AWS Console bypasses the pre-deployment gate. The runtime layer catches these, but only after the fact, and AWS Config evaluates on a schedule rather than immediately.

Platform policies that require a wildcard. AWS requires a wildcard resource for a small number of platform-level policies. The repo excludes those by name. Any real deployment will need a similar exception list.

There is a failure mode where the check passes because it cannot read the policy at all. I found this after the initial build and have written about it separately.

Repo structure
text
terraform/            infrastructure definitions
policies/             Rego policies evaluated by Conftest
lambda/transaction_api/   application code
.github/workflows/    CI/CD pipeline
scratch/              notes and working files
Running it
Requires Terraform 1.5+, OPA, Conftest, and an AWS account with credentials configured.

bash
cd terraform
terraform init
terraform plan -out=tfplan
terraform show -json tfplan > tfplan.json
conftest test tfplan.json --policy ../policies/ --all-namespaces
To see the gate work, break something in terraform/ that one of the policies covers and run the plan and test steps again. Conftest exits non-zero and prints the violation.

Stack
Terraform, Open Policy Agent, Conftest, Rego, GitHub Actions, AWS Lambda, API Gateway, DynamoDB, Cognito, AWS Config, CloudWatch.

Author
Victor Okoroafor
Built in public | LinkedIn
