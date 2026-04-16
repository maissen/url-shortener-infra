variable "name_prefix" {
  description = "Environment prefix (qa, staging, prod)"
  type        = string
}

variable "aws_region" {
  description = "AWS region"
  type        = string
}

variable "alert_emails" {
  description = "List of emails to subscribe to SNS alerts"
  type        = list(string)
}

variable "alb_arn_suffix" {
  description = "ALB ARN suffix (from aws_lb)"
  type        = string
}

variable "target_group_arn_suffix" {
  description = "Target group ARN suffix"
  type        = string
}

variable "ecs_cluster_name" {
  type = string
}

variable "ecs_service_name" {
  type = string
}

variable "dynamodb_table_name" {
  type = string
}

# auto scaling config
variable "min_capacity" {
  description = "Minimum number of ECS tasks"
  type        = number
}

variable "max_capacity" {
  description = "Maximum number of ECS tasks"
  type        = number
}

variable "cpu_target_value" {
  description = "Target CPU utilization percentage for autoscaling"
  type        = number
  default     = 60
}

variable "scale_in_cooldown" {
  description = "Cooldown period (seconds) before scaling in"
  type        = number
  default     = 300
}

variable "scale_out_cooldown" {
  description = "Cooldown period (seconds) before scaling out"
  type        = number
  default     = 60
}
