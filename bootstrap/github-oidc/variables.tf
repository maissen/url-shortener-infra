variable "aws_region" {
  description = "AWS region for all resources"
  type        = string
}

variable "backend_github_repo" {
  description = "GitHub repository in the format org/repo"
  type        = string
}

variable "terraform_github_repo" {
  description = "GitHub repository for Terraform (org/repo)"
  type        = string
}

variable "name_prefix_qa" {
  description = "Resource name prefix for the QA environment"
  type        = string
}

variable "name_prefix_staging" {
  description = "Resource name prefix for the Staging environment"
  type        = string
}

variable "name_prefix_prod" {
  description = "Resource name prefix for the Prod environment"
  type        = string
}

variable "ecr_repo_name" {
  description = "Base ECR repository name"
  type        = string
}

variable "ecs_cluster_name" {
  description = "Base ECS cluster name"
  type        = string
}

variable "ecs_service_name" {
  description = "Base ECS service name"
  type        = string
}

variable "ecs_task_def_name" {
  description = "Base ECS task definition name"
  type        = string
}

# Terraform remote state
variable "tf_state_bucket" {
  description = "S3 bucket name that holds Terraform remote state"
  type        = string
}

variable "tf_lock_table" {
  description = "DynamoDB table name used for Terraform state locking"
  type        = string
}
