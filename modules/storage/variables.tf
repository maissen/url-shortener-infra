variable "name_prefix" {
  description = "Prefix for all resource names"
  type        = string
}

variable "app_name" {
  description = "App name to prefix Parameter store's parameters with"
  type = string
}