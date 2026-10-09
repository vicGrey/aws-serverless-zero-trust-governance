<h1 align="center">🛡️ AWS Serverless Zero Trust Governance</h1>

<p align="center">
  <b>Block misconfigured infrastructure at the pull request. Catch drift after deployment.</b><br/>
  A Policy-as-Code governance framework for AWS serverless financial applications.
</p>

<p align="center">
  <img src="https://img.shields.io/badge/Terraform-7B42BC?style=for-the-badge&logo=terraform&logoColor=white" />
  <img src="https://img.shields.io/badge/Open_Policy_Agent-7D9199?style=for-the-badge&logo=openpolicyagent&logoColor=white" />
  <img src="https://img.shields.io/badge/GitHub_Actions-2088FF?style=for-the-badge&logo=github-actions&logoColor=white" />
  <img src="https://img.shields.io/badge/AWS-232F3E?style=for-the-badge&logo=amazon-aws&logoColor=white" />
</p>

<p align="center">
  <img src="https://img.shields.io/badge/Enforcement-100%25-2ea44f?style=flat-square" />
  <img src="https://img.shields.io/badge/False%20Positives-0%25-2ea44f?style=flat-square" />
  <img src="https://img.shields.io/badge/Gate%20Latency-7.3s-FF9900?style=flat-square" />
  <img src="https://img.shields.io/badge/Runtime%20Detection-3m%2030s-FF9900?style=flat-square" />
  <img src="https://img.shields.io/badge/Scenarios%20Tested-4-blue?style=flat-square" />
</p>

<p align="center">
  <a href="#problem">Problem</a> •
  <a href="#architecture">Architecture</a> •
  <a href="#flow">Flow</a> •
  <a href="#scenarios">Scenarios</a> •
  <a href="#results">Results</a> •
  <a href="#limitations">Limitations</a> •
  <a href="#run-it">Run It</a>
</p>

> 🎓 Built as an undergraduate project at the **Federal University of Technology, Minna**. The framework was designed, implemented, and tested against four misconfiguration scenarios. Results and limitations are documented honestly below.

---

<a id="problem"></a>

## 🔥 The Problem

Serverless shifts infrastructure configuration onto developers. Every Lambda needs an IAM execution role, every API endpoint needs an authorizer, and every S3 bucket needs a public access block. Get one wrong and **the deployment still succeeds**. Nothing fails. The misconfiguration just sits there until someone finds it.

Most tooling is reactive:

| Approach | The gap |
| :--- | :--- |
| 🔍 **Scanners** | Identify problems *after* deployment |
| ⏱️ **Runtime monitors** | Flag drift *on a schedule* |

Both leave a window between the misconfiguration existing and anyone knowing about it.

> ✅ **This framework closes that window at the earliest point it can: the pull request.**

---

<a id="architecture"></a>

## 🧱 Architecture

Three distinct layers, each covering a different moment in the lifecycle.

| Layer | What it does | Tools |
| :---: | :--- | :--- |
| 🚧 **1. Pre-deployment governance** | Terraform defines the infrastructure. On every push, GitHub Actions runs `terraform plan`, converts it to JSON, and evaluates it against Rego policies. A violation exits non-zero, the step fails, and the apply job never runs. Terraform never reaches the AWS API. | `Terraform` `OPA` `Conftest` `GitHub Actions` |
| ⚡ **2. Application** | The serverless financial API itself: Lambda for transaction logic, API Gateway for routing and JWT validation, DynamoDB for state, Cognito for identity. | `Lambda` `API Gateway` `DynamoDB` `Cognito` |
| 📡 **3. Runtime compliance** | AWS Config managed rules evaluate deployed resources against a baseline. A manual change made outside the pipeline is detected and flagged through CloudWatch alerts. | `AWS Config` `CloudWatch` |

```mermaid
flowchart LR
    A[👩💻 Developer] -->|push / PR| B[🚧 Layer 1<br/>Pre-deployment gate]
    B -->|policies pass| C[⚡ Layer 2<br/>Serverless financial API]
    C --> D[📡 Layer 3<br/>Runtime compliance]
    D -.->|drift alert| E[🔔 CloudWatch]
    B -.->|violation| F[⛔ Pipeline stops]

    style B fill:#7B42BC,color:#fff,stroke:#7B42BC
    style C fill:#FF9900,color:#fff,stroke:#FF9900
    style D fill:#2088FF,color:#fff,stroke:#2088FF
    style F fill:#d73a49,color:#fff,stroke:#d73a49
    style E fill:#2ea44f,color:#fff,stroke:#2ea44f
```

---

<a id="flow"></a>

## 🚀 How a Deployment Flows

```mermaid
flowchart TD
    A[commit to main] --> B[GitHub Actions:<br/>checkout, install, syntax check]
    B --> C[terraform plan → tfplan]
    C --> D[terraform show -json → tfplan.json]
    D --> E{conftest test<br/>tfplan.json<br/>--policy ../policies/}
    E -->|❌ fail| F[⛔ Pipeline stops.<br/>Apply job never runs.]
    E -->|✅ pass| G[terraform apply<br/>separate job, needs: validate]

    style E fill:#7B42BC,color:#fff,stroke:#7B42BC
    style F fill:#d73a49,color:#fff,stroke:#d73a49
    style G fill:#2ea44f,color:#fff,stroke:#2ea44f
```

> ⏱️ The gate adds about **7.3 seconds** to a pipeline run.

---

<a id="scenarios"></a>

## 🎯 Misconfiguration Scenarios

The policy library covers four specific scenarios. Each has a rule at the pre-deployment layer and, where applicable, at the runtime layer.

| | Scenario | What it catches | Rule type |
| :---: | :--- | :--- | :--- |
| 🔑 | **Over-privileged IAM roles** | `"Action": "*"` or `"Resource": "*"` in a policy document | `Rego` |
| 🪣 | **Publicly exposed S3 buckets** | Public access block disabled | `Rego` + `AWS Config` |
| 🚪 | **Unauthenticated API endpoints** | API Gateway method with no authorizer | `Rego` + `Custom Config rule` |
| 📝 | **Disabled execution logging** | API Gateway stage with no logging | `Rego` + `AWS Config` |

---

<a id="results"></a>

## 📊 Results

Tested against the four scenarios above.

| Metric | Result |
| :--- | :---: |
| ✅ **Enforcement success rate** | **100%** |
| 🎯 **Detection accuracy** | **100%** |
| 🚫 **False positive rate** | **0%** |
| ⚡ **Enforcement latency** | **7.3 s** |
| 📡 **Runtime detection latency** | **3 min 30 s** |
| 🌐 **API latency overhead** | **~46 ms** |

> [!NOTE]
> Four scenarios is a small sample. Read this as evidence the approach works, not as a definitive total detection rate.

---

<a id="limitations"></a>

## ⚠️ Limitations

Being upfront about what this doesn't catch.

<details>
<summary><b>🔤 Service-level wildcards</b></summary>
<br/>

The rule matches a bare `"*"`. A permission like `"s3:*"` is not caught and would need regex or pattern matching rather than an exact string comparison.
</details>

<details>
<summary><b>🖱️ Changes made outside the pipeline</b></summary>
<br/>

A resource created or modified directly in the AWS Console bypasses the pre-deployment gate. The runtime layer catches these, but only after the fact, and AWS Config evaluates on a schedule rather than immediately.
</details>

<details>
<summary><b>📋 Platform policies that require a wildcard</b></summary>
<br/>

AWS requires a wildcard resource for a small number of platform-level policies. The repository excludes those by name. Any real deployment will need a similar exception list.
</details>

<details>
<summary><b>🤫 Silent policy failures</b></summary>
<br/>

There is a failure mode where the check passes because it cannot read the policy at all. This requires separate validation to ensure policies are loaded correctly.
</details>

---

## 📁 Repository Structure

```text
├── 🏗️  terraform/                # Infrastructure definitions
├── 📜  policies/                 # Rego policies evaluated by Conftest
├── ⚡  lambda/transaction_api/   # Application code
├── 🤖  .github/workflows/        # CI/CD pipeline
└── 🗒️  scratch/                  # Notes and working files
```

---

<a id="run-it"></a>

## 🧪 Running It

### Prerequisites

- ![Terraform](https://img.shields.io/badge/Terraform-1.5+-7B42BC?style=flat-square&logo=terraform&logoColor=white)
- ![OPA](https://img.shields.io/badge/OPA-+_Conftest-7D9199?style=flat-square&logo=openpolicyagent&logoColor=white)
- ![AWS](https://img.shields.io/badge/AWS-account_with_local_credentials-FF9900?style=flat-square&logo=amazon-aws&logoColor=white)

### Local evaluation

```bash
cd terraform
terraform init
terraform plan -out=tfplan
terraform show -json tfplan > tfplan.json
conftest test tfplan.json --policy ../policies/ --all-namespaces
```

> 💡 **See the gate work:** break something in `terraform/` that one of the policies covers (for example, set an IAM `"Action": "*"`) and run the plan and test steps again. Conftest exits non-zero and prints the exact policy violation.

---

## 🧰 Tech Stack

<p>
  <img src="https://img.shields.io/badge/Terraform-7B42BC?style=for-the-badge&logo=terraform&logoColor=white" />
  <img src="https://img.shields.io/badge/Open_Policy_Agent-7D9199?style=for-the-badge&logo=openpolicyagent&logoColor=white" />
  <img src="https://img.shields.io/badge/Conftest-Rego-4B5563?style=for-the-badge" />
  <img src="https://img.shields.io/badge/GitHub_Actions-2088FF?style=for-the-badge&logo=github-actions&logoColor=white" />
</p>
<p>
  <img src="https://img.shields.io/badge/AWS_Lambda-FF9900?style=for-the-badge&logo=awslambda&logoColor=white" />
  <img src="https://img.shields.io/badge/API_Gateway-FF4F8B?style=for-the-badge&logo=amazon-api-gateway&logoColor=white" />
  <img src="https://img.shields.io/badge/DynamoDB-4053D6?style=for-the-badge&logo=amazondynamodb&logoColor=white" />
  <img src="https://img.shields.io/badge/Cognito-DD344C?style=for-the-badge&logo=amazon-aws&logoColor=white" />
</p>
<p>
  <img src="https://img.shields.io/badge/AWS_Config-232F3E?style=for-the-badge&logo=amazon-aws&logoColor=white" />
  <img src="https://img.shields.io/badge/CloudWatch-E7157B?style=for-the-badge&logo=amazoncloudwatch&logoColor=white" />
</p>

---

## 👤 Author

<table>
  <tr>
    <td>
      <b>Victor Okoroafor</b><br/>
      AWS Certified Cloud Engineer | DevSecOps &amp; Cloud Security<br/><br/>
      <a href="https://linkedin.com/in/victor-okoroafor-cloud"><img src="https://img.shields.io/badge/LinkedIn-0A66C2?style=for-the-badge&logo=linkedin&logoColor=white" /></a>
      <a href="mailto:victor.okoroafor.cloud@gmail.com"><img src="https://img.shields.io/badge/Email-EA4335?style=for-the-badge&logo=gmail&logoColor=white" /></a>
      <a href="https://github.com/vicGrey"><img src="https://img.shields.io/badge/GitHub-181717?style=for-the-badge&logo=github&logoColor=white" /></a>
    </td>
  </tr>
</table>

<p align="center">
  <sub>⭐ If this helped you think about shifting cloud security left, consider starring the repo.</sub>
</p>
