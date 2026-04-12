output "dynamodb_table_name" {
  value = aws_dynamodb_table.urls.name
}

output "dynamodb_table_arn" {
  value = aws_dynamodb_table.urls.arn
}