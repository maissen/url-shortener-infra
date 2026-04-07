output "environment" {
  description = "Deployment environment (staging or prod)"
  value       = var.environment
}

output "app_url" {
  description = "Application entrypoint URL"
  value       = "http://${module.compute.alb_dns_name}"
}

output "vpc_id" {
  description = "VPC ID (useful for debugging and integrations)"
  value       = module.networking.vpc_id
}

output "alb_dns_name" {
  description = "DNS name of the Application Load Balancer"
  value       = module.compute.alb_dns_name
}

output "alb_zone_id" {
  description = "Zone ID of the ALB (used for Route53 alias records)"
  value       = module.compute.alb_zone_id
}

output "ecs_cluster_name" {
  description = "ECS cluster name"
  value       = module.compute.ecs_cluster_name
}

output "ecs_service_name" {
  description = "ECS service name"
  value       = module.compute.ecs_service_name
}

output "ecr_repository_url" {
  description = "ECR repository URL for pushing/pulling images"
  value       = var.ecr_repo_url
}