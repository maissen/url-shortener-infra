variable "name_prefix" {
  description = "Prefix for all resource names (staging, prod)"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID"
  type        = string
}

variable "public_subnet_ids" {
  description = "Public subnet IDs for ALB"
  type        = list(string)
}

variable "private_subnet_ids" {
  description = "Private subnet IDs for ECS tasks"
  type        = list(string)
}

variable "image" {
  description = "Container image (ECR URL)"
  type        = string
}

variable "container_port" {
  description = "Container port"
  type        = number
}

variable "container_name" {
  description = "Container name"
  type        = string
}

variable "desired_count" {
  description = "Desired count for ECS tasks"
  type = number
  default = 1
}

variable "enable_deletion_protection" {
  description = "Enable deletion protection for ALB"
  type = bool
  default = true
}

variable "aws_region" {
  description = "AWS region (also used for CloudWatch log group region)"
  type        = string
}

variable "dynamodb_table_arn" {
  description = "ARN of the DynamoDB table the ECS task is allowed to access"
  type        = string
}

variable "app_name" {
  description = "Application name, used to namespace SSM parameters"
  type        = string
}
