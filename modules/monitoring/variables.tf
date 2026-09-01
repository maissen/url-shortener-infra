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
  default     = 80
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

variable "ecs_cpu_high_threshold" {
  description = "CPU utilization percentage threshold to trigger high-CPU alarm"
  type        = number
  default     = 80
}

variable "ecs_memory_high_threshold" {
  description = "Memory utilization percentage threshold to trigger high-memory alarm"
  type        = number
  default     = 80
}

variable "alb_5xx_rate_threshold" {
  description = "5xx error rate percentage threshold to trigger alarm"
  type        = number
  default     = 1
}

variable "alb_unhealthy_hosts_threshold" {
  description = "Unhealthy host count threshold to trigger alarm"
  type        = number
  default     = 0
}