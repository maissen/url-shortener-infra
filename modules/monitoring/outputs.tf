output "sns_topic_arn" {
  description = "SNS topic ARN for alerts"
  value       = aws_sns_topic.alerts.arn
}

output "sns_topic_name" {
  description = "SNS topic name"
  value       = aws_sns_topic.alerts.name
}

output "autoscaling_target_arn" {
  description = "ECS autoscaling target resource ID"
  value       = aws_appautoscaling_target.ecs.resource_id
}

output "autoscaling_policy_name" {
  description = "ECS CPU autoscaling policy name"
  value       = aws_appautoscaling_policy.ecs_cpu.name
}