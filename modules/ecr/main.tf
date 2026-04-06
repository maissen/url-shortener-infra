# ECR private repository
resource "aws_ecr_repository" "ecr" {
  name                 = "${name_prefix}-${repository_name}"
  image_tag_mutability = "IMMUTABLE"
}