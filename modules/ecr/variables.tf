variable "name_prefix" {
  description = "Prefix for all resource names (staging, prod)"
  type        = string
}

variable "repository_name" {
  description = "Base name of the ECR repository"
  type        = string
}