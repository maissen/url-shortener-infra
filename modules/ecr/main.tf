# ECR private repository
resource "aws_ecr_repository" "ecr" {
  name                 = "${var.name_prefix}-${var.repository_name}"
  image_tag_mutability = "IMMUTABLE"
}