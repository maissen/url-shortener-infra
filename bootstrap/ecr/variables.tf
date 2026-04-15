variable "aws_region" {
  description = "AWS region for bootstrap resources"
  type        = string
}

variable "repository_name" {
  description = "Base name of the ECR repository"
  type        = string
}

variable "scan_on_push" {
  description = "Enable/Disable image scanning on push"
  type        = bool
  default     = true
}

variable "tagged_images_to_keep" {
  description = "Number of tagged images to retain in ECR"
  type        = number
  default     = 20
}

variable "mutable_tag_prefixes" {
  description = "List of mutable tags"
  type        = list(string)
  default     = []
}