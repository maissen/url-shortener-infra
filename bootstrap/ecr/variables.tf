variable "aws_region" {
  description = "AWS region for bootstrap resources"
  type        = string
}

variable "name_prefix" {
  description = "Prefix for all resource names (staging, prod)"
  type        = string
}

variable "repository_name" {
  description = "Base name of the ECR repository"
  type        = string
}

variable "scan_on_push" {
  description = "Enable/Disable image scanning on push"
  type = bool
  default = true
}

variable "tagged_images_to_keep" {
  description = "Number of tagged images to retain in ECR"
  type        = number
  default     = 20
}