# URL Shortener, AWS Infrastructure

A production-grade infrastructure for a URL shortener API, simulating real-world DevOps practices across three environments **(QA, staging, prod)**. Built with Terraform modules, GitHub Actions CI/CD, OIDC authentication, and full observability via CloudWatch. Every decision here, from network topology to the deployment pipeline, reflects how infrastructure is actually managed at companies that care about operational maturity.


## Architecture

![Architecture Diagram](docs/architecture.png)

The system runs on AWS inside a VPC spread across two availability zones. Each AZ has a public and a private subnet. The Application Load Balancer lives in the public subnets. ECS Fargate tasks run in the private subnets and are never publicly reachable, inbound traffic flows only from the ALB's security group. A NAT Gateway in each public subnet gives tasks outbound internet access for pulling ECR images and reaching AWS APIs.

DynamoDB handles persistence. The access pattern for a URL shortener (key-value lookups by short code) maps naturally to DynamoDB's model, and it avoids the operational overhead of managing a database server. SSM Parameter Store holds any configuration the application needs at runtime. Route 53 routes `maissen.tech` (prod), `staging.maissen.tech` (staging), and `qa.maissen.tech` (QA) to their respective ALBs via alias records.

Three environments, **QA**, **staging**, and **prod**, are separate Terraform state files applied from the same modules with different variable inputs.

---

## Screenshots

**CloudWatch dashboard, prod environment**
<!-- Screenshot: The CloudWatch dashboard showing live metrics, ALB request count, ECS CPU/memory, DynamoDB consumed capacity. Captures that monitoring is actually configured and running. -->
![CloudWatch dashboard](docs/cloudwatch-dashboard.png)

<!-- **Live endpoint, curl output** -->
<!-- Screenshot: Terminal showing `curl -i https://api.yourdomain.xyz/health` returning HTTP 200 with the JSON response and a valid TLS certificate. Simple but proves the stack is end-to-end working. -->
<!-- ![Health check response](docs/screenshots/health-check-curl.png)

> **Note on screenshots vs GIFs:** Use a GIF for the pipeline run (it conveys the sequential nature of the stages better than a static screenshot). Use static screenshots for the dashboard and curl output, they're cleaner and load faster. -->

---

## Repository Structure

```
.
├── bootstrap/
│   ├── remote-state/         # S3 bucket + DynamoDB lock table, applied once manually
│   ├── github-oidc/          # IAM identity provider + role for GitHub Actions OIDC
│   └── ecr/                  # ECR repository for application images
│
├── environments/
│   ├── qa/                   # QA environment, auto-applied on merge to main
│   ├── staging/              # Staging environment, requires manual approval to apply
│   └── prod/                 # Prod environment, requires manual approval to apply
│
└── modules/
    ├── networking/            # VPC, subnets, IGW, NAT, route tables, VPC flow logs
    ├── compute/               # ECS cluster, task definition, service, IAM roles, ALB
    ├── storage/               # DynamoDB table, SSM parameters
    └── monitoring/            # CloudWatch log groups, dashboard, alarms, SNS topic
```

Bootstrap resources are intentionally separated from environment infrastructure. They are applied once and never touched afterward. Modules contain no environment-specific logic, all variation comes from variables passed in by each environment's `main.tf`.

---

## How to Deploy

**Prerequisites:** AWS CLI configured, Terraform >= 1.6, Docker, pre-commit.

**1. Install pre-commit hooks** (run once after cloning):

```bash
pip install pre-commit
pre-commit install
```

**2. Bootstrap remote state** (run once, manually):

```bash
cd bootstrap/remote-state
terraform init
terraform apply
```

> Before running `terraform init` in any directory with a `backend.hcl`, update that file with your actual S3 bucket name, key path, and region. Remote state must exist before any environment can be initialized.

**3. Bootstrap OIDC trust for GitHub Actions** (run once):

```bash
cd ../github-oidc
terraform init -backend-config=backend.hcl
terraform apply
```

**4. Bootstrap ECR repository** (run once):

```bash
cd ../ecr
terraform init -backend-config=backend.hcl
terraform apply
```

**5. Push an initial image to ECR:**

```bash
aws ecr get-login-password --region AWS_REGION | \
  docker login --username AWS --password-stdin AWS_ACCOUNT_ID.dkr.ecr.AWS_REGION.amazonaws.com

docker build -t ECR_REPO_NAME:latest DOCKERFILE_PATH
docker tag ECR_REPO_NAME:latest AWS_ACCOUNT_ID.dkr.ecr.AWS_REGION.amazonaws.com/ECR_REPO_NAME:latest
docker push AWS_ACCOUNT_ID.dkr.ecr.AWS_REGION.amazonaws.com/ECR_REPO_NAME:latest
```

**6. Deploy an environment:**

```bash
cd environments/staging
terraform init -backend-config=backend.hcl
terraform apply -var-file=terraform.tfvars
```

---

## How to Work With This

**First-time setup** requires the three bootstrap steps in order: `remote-state` → `github-oidc` → `ecr`. These are applied manually from a local terminal with appropriate AWS credentials.

**Environment-specific values** live at `environments/<env>/terraform.tfvars`. Anything that differs between environments, task counts, alarm thresholds, domain names, tags, lives here. Nothing environment-specific is hardcoded in modules.

**Image deployments** are handled by the application pipeline in the [backend repo](https://github.com/maissen/url-shortener-backend). On merge to main, it builds the Docker image, tags it with the git commit SHA, pushes to ECR, and updates the ECS service in QA automatically.

---

## Security

**IAM roles are split by concern.** The ECS task execution role gives ECS permission to pull images from ECR and write logs to CloudWatch. The task role gives the application permission to read from DynamoDB and fetch its SSM parameters, nothing else. Both roles are scoped to specific resource ARNs, not wildcards.

**Security groups follow least privilege.** The ECS security group accepts traffic only from the ALB's security group on the application port. No direct inbound access to tasks from the internet.

**Secrets come from SSM Parameter Store.** The task definition references parameter ARNs, values are injected at container startup by ECS. No sensitive values appear in environment variable blocks, Terraform state, or source code.

**ECR image scanning is enabled on push.** Every image is automatically scanned for known CVEs on arrival. The application pipeline also runs Trivy before pushing, providing a second layer of scanning before an image reaches the registry.

---

## Monitoring

CloudWatch handles observability. Each environment writes structured JSON logs to a dedicated log group with a defined retention period.

A CloudWatch dashboard per environment displays: ALB request count, ALB 4xx and 5xx error rates, ECS CPU and memory utilization, and DynamoDB consumed read/write capacity, on a single screen.

Alarms fire when ECS CPU or memory exceeds a defined threshold for a sustained period, or when the ALB 5xx error rate exceeds a defined threshold. All alarms publish to an SNS topic that delivers to email. A composite alarm aggregates the critical signals. ECS service autoscaling targets a defined CPU utilization threshold, with a minimum task count on prod (ensuring real cross-AZ high availability) and a lower minimum on QA and staging.

---

## Cost Estimate

Running the full three-environment stack continuously costs approximately **$250–310/month**. The table below breaks down the main cost drivers based on current us-east-1 pricing.

| Service | Per environment | Notes |
|---|---|---|
| NAT Gateway | ~$33/month each | Largest fixed cost, $0.045/hr per gateway, regardless of traffic |
| ALB | ~$18–22/month each | Base LCU cost, scales with traffic |
| ECS Fargate | ~$15–30/month each | Depends on task size and count; 0.25 vCPU / 0.5 GB baseline |
| DynamoDB | ~$0–2/month | On-demand mode; well within always-free tier at low traffic |
| CloudWatch | ~$3–8/month each | Logs ingestion + dashboard + alarms |
| ECR | ~$1/month | Storage for recent images; lifecycle policy keeps this near zero |

> Cost estimates are approximations based on us-east-1 pricing as of April 2026. Actual costs vary by region, traffic volume, and log ingestion rate.