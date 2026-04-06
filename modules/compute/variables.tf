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

variable "environment" {
  description = "Environment name (staging/prod)"
  type        = string
}