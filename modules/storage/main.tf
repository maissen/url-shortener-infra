resource "aws_dynamodb_table" "urls" {
  name         = "${var.name_prefix}-urls"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "code"

  attribute {
    name = "code"
    type = "S"
  }

  tags = {
    Environment = var.name_prefix
  }
}

resource "aws_ssm_parameter" "dynamodb_table_name" {
  name  = "/${var.app_name}/${var.name_prefix}/dynamodb_table_name"
  type  = "String"
  value = aws_dynamodb_table.urls.name
}

resource "aws_ssm_parameter" "base_url" {
  name  = "/${var.app_name}/${var.name_prefix}/base_url"
  type  = "String"
  value = var.base_url
}