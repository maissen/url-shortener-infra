# URL Shortener app's infra on AWS using Terraform

A production-grade infrastructure for a URL shortener API, simulating real-world DevOps practices across three environments **(QA, staging, prod)**. Built with Terraform modules, GitHub Actions CI/CD, OIDC authentication, and full observability via CloudWatch. Every decision here, from the network topology to the deployment pipeline reflects how infrastructure is actually managed at companies that care about operational maturity.

---

## Architecture

![Architecture Diagram](docs/architecture.png)

- The system runs on AWS inside a VPC spread across two availability zones. Each AZ has a public and a private subnet. The Application Load Balancer lives in the public subnets and terminates HTTPS using an ACM-managed certificate. ECS Fargate tasks run in the private subnets and are never publicly reachable, inbound traffic flows only from the ALB's security group. A NAT Gateway in each public subnet gives tasks outbound internet access for pulling ECR images and reaching AWS APIs.

- DynamoDB handles persistence. The access pattern for a URL shortener (key-value lookups by short code) maps naturally to DynamoDB's model. SSM Parameter Store holds any configuration the application needs at runtime. Route 53 routes `yourdomain.xyz` (prod), `staging.yourdomain.xyz` (staging) and `qa.yourdomain.xyz` (QA) to their respective ALBs via alias records.

- Three environments: **QA**, **staging** and **prod** are separate Terraform state files applied from the same modules with different variable inputs.

---

## How to Deploy

**Prerequisites:** AWS CLI configured or Docker, Terraform >= 1.6, pre-commit installed.

1- Install pre-commit hooks (run once after cloning):
```bash
pip install pre-commit
pre-commit install
```

2- Bootstrap remote state (run once, manually):
```bash
cd bootstrap/remote-state
terraform init
terraform apply
```

> **Important:** Before running `terraform init` in any directory with a `backend.hcl`, update that file with your actual S3 bucket name, key path, and region. Remote state must exist before any environment can be initialized.

3- Bootstrap OIDC trust for GitHub Actions (run once):
```bash
cd ../github-oidc
terraform init -backend-config=backend.hcl
terraform apply
```

4- Bootstrap ECR repository (run once):
```bash
cd ../ecr
terraform init -backend-config=backend.hcl
terraform apply
```

5- Authenticate to AWS ECR and push initial image (replace `AWS_REGION`, `AWS_ACCOUNT_ID`, `ECR_REPO_NAME`, `DOCKERFILE_PATH`):
```bash
aws ecr get-login-password --region AWS_REGION 
```
**OR**
```bash
docker login --username AWS --password-stdin AWS_ACCOUNT_ID.dkr.ecr.AWS_REGION.amazonaws.com 
```

6- Build and push Docker image:
```bash
docker build -t ECR_REPO_NAME:latest DOCKERFILE_PATH
docker tag ECR_REPO_NAME:latest AWS_ACCOUNT_ID.dkr.ecr.AWS_REGION.amazonaws.com/ECR_REPO_NAME:latest
docker push AWS_ACCOUNT_ID.dkr.ecr.AWS_REGION.amazonaws.com/ECR_REPO_NAME:latest
```

> **Note:** After pushing the initial image, CI/CD will handle subsequent deployments automatically.

7- Deploy an environment:
```bash
cd environments/staging
terraform init -backend-config=backend.hcl
terraform apply -var-file=terraform.tfvars
```

> Edit `backend.hcl` with your S3 bucket and state key before running the above.

---

## Repository Structure

```
.
├── .github/workflows/        # CI/CD pipelines for Terraform
│
├── bootstrap/
│   ├── remote-state/         # S3 bucket + DynamoDB lock table -> applied once manually
│   ├── github-oidc/          # IAM identity provider + role for GitHub Actions
│   └── ecr/                  # ECR repository for application images
│
├── environments/
│   ├── qa/                   # QA environment -> auto-applied on merge to main
│   ├── staging/              # Staging environment -> requires manual approval to apply
│   └── prod/                 # Prod environment -> requires manual approval to apply
│
└── modules/
    ├── networking/            # VPC, subnets, IGW, NAT, route tables, flow logs
    ├── compute/               # ECS cluster, task definition, service, IAM roles, ALB
    ├── storage/               # DynamoDB table, SSM parameters
    └── monitoring/            # CloudWatch log groups, dashboard, alarms, SNS topic
```

Bootstrap resources are intentionally separated from environment infrastructure. They are applied once and never touched by the automated pipeline. Modules contain no environment-specific logic, all variation comes from variables passed in by each environment's `main.tf`.

---

## How to work with

**First-time setup** requires the three bootstrap steps in order: `remote-state` → `github-oidc` → `ecr`. These are applied manually from a local terminal with appropriate AWS credentials. After that, all infrastructure changes flow through the CI/CD pipeline.

**Updating infrastructure** works through pull requests. Open a PR against `main`, the pipeline runs `fmt`, `validate`, `tflint`, and `terraform plan` for all three environments, posting plan output as a PR comment. Merge triggers an automatic apply to QA. After QA is verified, a manual approval gate controls the staging and prod apply.

**Environment variable files** live at `environments/<env>/variables.tf`. Anything that differs between environments: instance counts, alarm thresholds, domain names, tags, ... lives here. *Nothing environment-specific is hardcoded in modules*.

**Image deployments** are handled by the application pipeline [backend repo](https://github.com/maissen/url-shortener-backend). On merge to main, it builds the Docker image, tags and pushes it to ECR, and updates the ECS service in QA automatically.

---
## CI/CD

Three workflows live in `.github/workflows/`:

**`terraform.yaml`** : the main orchestrator. Triggers on pull requests and pushes to `main`. On PR: runs `_plan.yaml` for all environments and posts results as comments. On merge: runs `_apply.yaml` for QA automatically, then waits for manual approval before applying to Staging and Prod.

**`_plan.yaml`** : reusable workflow. Runs `fmt -check`, `validate`, `tflint`, and `plan` for a given environment. Called by the orchestrator with the target environment as input.

**`_apply.yaml`** : reusable workflow. Runs `apply -auto-approve` for a given environment. Requires the plan to have run in the same pipeline execution.

### GitHub Setup

Create three GitHub Actions environments in your repository settings:
- `qa`
- `staging`
- `prod`

Configure the `prod` and `staging` environments with a required reviewers for manual approval before deployments.

Declare the following variables in your repository's **Variables** section:
- `AWS_REGION` : AWS region for all deployments
- `TF_VERSION` : Terraform version to use in workflows

**For each environment**, declare an environment-specific variable:
- `AWS_ROLE_ARN_QA` : IAM role ARN for QA deployments
- `AWS_ROLE_ARN_STAGING` : IAM role ARN for Staging deployments
- `AWS_ROLE_ARN_PROD` : IAM role ARN for Production deployments

---

## Security

**IAM roles are split by concern.** The ECS task execution role gives ECS permission to pull images from ECR and ship logs to CloudWatch. The task role gives the application permission to read from DynamoDB and fetch its SSM parameters.

**Security groups follow least privilege.** The ALB security group accepts HTTPS from `0.0.0.0/0`. The ECS security group accepts traffic only from the ALB's security group on the application port. No direct inbound access to tasks from the internet.

**Secrets come from SSM Parameter Store.** The task definition references parameter ARNs, values are injected at container startup. No sensitive values in environment variables or Terraform state.

---

## Monitoring

CloudWatch handles observability. Each ECS environment writes structured JSON logs to a dedicated log group with x-day retention.

A CloudWatch dashboard per environment displays key metrics including ALB request count, ECS CPU and memory utilization, and DynamoDB consumed capacity on one screen.

Alarms fire when ECS CPU or memory exceeds thresholds, or when the ALB error rate spikes. All alarms publish to an SNS topic that delivers to email. A composite alarm aggregates the critical signals into a single pane. ECS service autoscaling is configured on **CPU utilization**.

---

## Lessons Learned

The piece of this project that forced the most real thinking was IAM. The surface area seems small, two roles per ECS service, but getting it genuinely right took several iterations. The first version of the task role was too broad because it was easier to test with more permissions and the plan was to tighten it later. "Later" kept getting pushed. Eventually I sat down and worked out exactly which DynamoDB actions the application actually calls and which SSM parameter paths it needs, and wrote the policy to match that exactly. The discipline required to do that upfront rather than defaulting to `*` on resources is something I now build in from the start.

The second thing I underestimated was remote state sequencing. The bootstrap components have an implicit dependency order: `remote-state` must exist before anything else can use a backend, `github-oidc` must exist before the pipeline can authenticate, `ecr` must exist before the pipeline can push images. None of this is enforced by Terraform, it's just operational knowledge. Documenting the correct order explicitly, and understanding why each piece exists before the others, removed a class of confusion that would otherwise show up during any disaster recovery scenario.

If I were scaling this further, I'd separate the state bucket per environment rather than using key prefixes in one bucket. It's a small change now, a significant blast radius reduction later. I'd also move the CloudWatch dashboard definitions into a templating layer rather than static Terraform resources, they become brittle as metrics change and rebuilding them by hand doesn't scale. Both are the kind of tradeoff that only becomes visible when you've lived with the system for a while.