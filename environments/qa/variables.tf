variable "environment" {
  description = "Environment name (staging, prod, qa)"
  type        = string
}

variable "region" {
  description = "AWS region"
  type        = string
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "azs" {
  description = "List of availability zones to use"
  type        = list(string)
}

variable "public_subnet_cidrs" {
  description = "List of CIDR blocks for public subnets"
  type        = list(string)
}

variable "private_subnet_cidrs" {
  description = "List of CIDR blocks for private subnets"
  type        = list(string)
}

variable "ecr_repo_url" {
  description = "ECR repository url"
  type        = string
}

variable "container_name" {
  description = "Name of the container"
  type        = string
}

variable "container_port" {
  description = "Port on which the container listens"
  type        = number
}

variable "image_tag" {
  description = "Docker image tag to deploy (from ECR)"
  type        = string
}

variable "desired_count" {
  description = "Desired number of tasks/containers"
  type        = number
  default     = 1
}

variable "enable_alb_deletion_protection" {
  description = "Enable deletion protection for ALB"
  type        = bool
  default     = true
}

variable "app_name" {
  description = "App name to prefix Parameter store's parameters with"
}

variable "alert_emails" {
  description = "List of emails to receive CloudWatch alerts"
  type        = list(string)
}