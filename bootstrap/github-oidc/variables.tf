variable "aws_region" {
  description = "AWS region for bootstrap resources"
  type        = string
}

variable "github_repo" {
  description = "GitHub repository in the format org/repo"
  type        = string
}

variable "ecr_repo_name" {
  description = "Name of the ECR repository"
  type        = string
}

variable "staging_ecs_cluster_name" {
  description = "Staging ECS cluster name"
  type        = string
}

variable "staging_ecs_service_name" {
  description = "Staging ECS service name"
  type        = string
}

variable "prod_ecs_cluster_name" {
  description = "Prod ECS cluster name"
  type        = string
}

variable "prod_ecs_service_name" {
  description = "Prod ECS service name"
  type        = string
}

variable "github_role_name" {
  description = "Name of the GitHub Actions IAM role"
  type        = string
  default     = "github-actions-deploy-role"
}

variable "github_policy_name" {
  description = "Name of the IAM policy for GitHub Actions"
  type        = string
  default     = "github-actions-deploy-policy"
}