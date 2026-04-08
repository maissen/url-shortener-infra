# ECR private repository
resource "aws_ecr_repository" "ecr" {
  name = "${var.repository_name}"
  image_tag_mutability = length(var.mutable_tag_prefixes) > 0 ? "MUTABLE" : "IMMUTABLE"

  image_scanning_configuration {
    scan_on_push = var.scan_on_push
  }
}

# resource "aws_ecr_lifecycle_policy" "this" {
#   repository = aws_ecr_repository.ecr.name

#   policy = jsonencode({
#     rules = [
#       {
#         rulePriority = 1
#         description  = "Keep last ${var.tagged_images_to_keep} tagged images"
#         selection = {
#           tagStatus     = "tagged"
#           tagPrefixList = [var.name_prefix]
#           countType     = "imageCountMoreThan"
#           countNumber   = var.tagged_images_to_keep
#         }
#         action = {
#           type = "expire"
#         }
#       },
#       {
#         rulePriority = 2
#         description  = "Delete untagged images after 1 day"
#         selection = {
#           tagStatus   = "untagged"
#           countType   = "sinceImagePushed"
#           countUnit   = "days"
#           countNumber = 1
#         }
#         action = {
#           type = "expire"
#         }
#       }
#     ]
#   })
# }