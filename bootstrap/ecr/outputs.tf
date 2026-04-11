output "repository_url" {
  description = "ECR repository URL (used to push/pull images)"
  value       = aws_ecr_repository.ecr.repository_url
}

output "repository_arn" {
  description = "ECR repository ARN"
  value       = aws_ecr_repository.ecr.arn
}