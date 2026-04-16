variable "name_prefix" {
  description = "Environment prefix (qa, staging, prod)"
  type        = string
}

variable "alert_emails" {
  description = "List of emails to subscribe to SNS alerts"
  type        = list(string)
}