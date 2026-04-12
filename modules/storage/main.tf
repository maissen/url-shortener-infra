resource "aws_dynamodb_table" "urls" {
  name         = "${var.name_prefix}-url-shortener"
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