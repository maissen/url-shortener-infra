output "oidc_provider_arn" {
  description = "ARN of the GitHub OIDC provider"
  value       = aws_iam_openid_connect_provider.github.arn
}

# Backend role ARNs
output "backend_role_arn_qa" {
  description = "ARN of the QA backend deploy role"
  value       = aws_iam_role.backend["qa"].arn
}

output "backend_role_arn_staging" {
  description = "ARN of the Staging backend deploy role"
  value       = aws_iam_role.backend["staging"].arn
}

output "backend_role_arn_prod" {
  description = "ARN of the Prod backend deploy role"
  value       = aws_iam_role.backend["prod"].arn
}

# Terraform role ARNs
output "terraform_role_arn_qa" {
  description = "ARN of the QA Terraform role"
  value       = aws_iam_role.terraform["qa"].arn
}

output "terraform_role_arn_staging" {
  description = "ARN of the Staging Terraform role"
  value       = aws_iam_role.terraform["staging"].arn
}

output "terraform_role_arn_prod" {
  description = "ARN of the Prod Terraform role"
  value       = aws_iam_role.terraform["prod"].arn
}
