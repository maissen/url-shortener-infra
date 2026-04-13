variable "aws_region" {
  description = "AWS region for all resources"
  type        = string
}

variable "github_repo" {
  description = "GitHub repository in the format org/repo (e.g. maissen/url-shortener-backend)"
  type        = string
}

variable "name_prefix_qa" {
  description = "Resource name prefix for the QA environment (e.g. url-shortener-qa)"
  type        = string
}

variable "name_prefix_staging" {
  description = "Resource name prefix for the Staging environment (e.g. url-shortener-staging)"
  type        = string
}

variable "name_prefix_prod" {
  description = "Resource name prefix for the Prod environment (e.g. url-shortener-prod)"
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
