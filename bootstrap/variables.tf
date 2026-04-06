variable "aws_region" {
  description = "AWS region for bootstrap resources"
  type        = string
}

variable "bucket_name" {
  description = "S3 bucket name for terraform state"
  type        = string
}

variable "dynamodb_table_name" {
  description = "DynamoDB table name for state locking"
  type        = string
}