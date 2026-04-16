# SNS Topic
resource "aws_sns_topic" "alerts" {
  name = "${var.name_prefix}-alerts-topic"
}

resource "aws_sns_topic_subscription" "email_subscriptions" {
  for_each = toset(var.alert_emails)

  topic_arn = aws_sns_topic.alerts.arn
  protocol  = "email"
  endpoint  = each.value
}

resource "aws_cloudwatch_dashboard" "main" {
  dashboard_name = "${var.name_prefix}-dashboard"

  dashboard_body = jsonencode({
    widgets = [

      # Widget 1 : ALB Request Count
      {
        type   = "metric"
        x      = 0
        y      = 0
        width  = 12
        height = 6

        properties = {
          title  = "ALB Request Count"
          region = var.aws_region
          period = 60
          stat   = "Sum"

          metrics = [
            [
              "AWS/ApplicationELB",
              "RequestCount",
              "LoadBalancer", var.alb_arn_suffix
            ]
          ]
        }
      },

      # Widget 2 : ALB 4xx Error Rate
      {
        type   = "metric"
        x      = 12
        y      = 0
        width  = 12
        height = 6

        properties = {
          title  = "ALB 4xx Error Rate (%)"
          region = var.aws_region
          period = 60

          metrics = [
            [
              "AWS/ApplicationELB",
              "HTTPCode_Target_4XX_Count",
              "LoadBalancer", var.alb_arn_suffix,
              { id = "m1", stat = "Sum" }
            ],
            [
              ".",
              "RequestCount",
              ".",
              ".",
              { id = "m2", stat = "Sum" }
            ],
            [
              { expression = "100 * (m1 / m2)", label = "4xx %", id = "e1" }
            ]
          ]
        }
      },

      # Widget 3 : ALB 5xx Error Rate
      {
        type   = "metric"
        x      = 0
        y      = 6
        width  = 12
        height = 6

        properties = {
          title  = "ALB 5xx Error Rate (%)"
          region = var.aws_region
          period = 60

          metrics = [
            [
              "AWS/ApplicationELB",
              "HTTPCode_Target_5XX_Count",
              "LoadBalancer", var.alb_arn_suffix,
              { id = "m1", stat = "Sum" }
            ],
            [
              ".",
              "RequestCount",
              ".",
              ".",
              { id = "m2", stat = "Sum" }
            ],
            [
              { expression = "100 * (m1 / m2)", label = "5xx %", id = "e1" }
            ]
          ]
        }
      },

      # Widget 4 : ECS CPU
      {
        type   = "metric"
        x      = 12
        y      = 6
        width  = 12
        height = 6

        properties = {
          title  = "ECS CPU Utilization"
          region = var.aws_region
          stat   = "Average"

          metrics = [
            [
              "AWS/ECS",
              "CPUUtilization",
              "ClusterName", var.ecs_cluster_name,
              "ServiceName", var.ecs_service_name
            ]
          ]
        }
      },

      # Widget 5 : ECS Memory
      {
        type   = "metric"
        x      = 0
        y      = 12
        width  = 12
        height = 6

        properties = {
          title  = "ECS Memory Utilization"
          region = var.aws_region
          stat   = "Average"

          metrics = [
            [
              "AWS/ECS",
              "MemoryUtilization",
              "ClusterName", var.ecs_cluster_name,
              "ServiceName", var.ecs_service_name
            ]
          ]
        }
      },

      # Widget 6 : DynamoDB Reads
      {
        type   = "metric"
        x      = 12
        y      = 12
        width  = 12
        height = 6

        properties = {
          title  = "DynamoDB Read Capacity"
          region = var.aws_region

          metrics = [
            [
              "AWS/DynamoDB",
              "ConsumedReadCapacityUnits",
              "TableName", var.dynamodb_table_name
            ]
          ]
        }
      },

      # Widget 7 : DynamoDB Writes
      {
        type   = "metric"
        x      = 0
        y      = 18
        width  = 24
        height = 6

        properties = {
          title  = "DynamoDB Write Capacity"
          region = var.aws_region

          metrics = [
            [
              "AWS/DynamoDB",
              "ConsumedWriteCapacityUnits",
              "TableName", var.dynamodb_table_name
            ]
          ]
        }
      }
    ]
  })
}

resource "aws_cloudwatch_metric_alarm" "ecs_cpu_high" {
  alarm_name          = "${var.name_prefix}-ecs-cpu-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 5
  datapoints_to_alarm = 5
  threshold           = 80

  namespace   = "AWS/ECS"
  metric_name = "CPUUtilization"
  statistic   = "Average"
  period      = 60

  dimensions = {
    ClusterName = var.ecs_cluster_name
    ServiceName = var.ecs_service_name
  }

  alarm_actions = [aws_sns_topic.alerts.arn]
}

resource "aws_cloudwatch_metric_alarm" "ecs_memory_high" {
  alarm_name          = "${var.name_prefix}-ecs-memory-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 5
  datapoints_to_alarm = 5
  threshold           = 80

  namespace   = "AWS/ECS"
  metric_name = "MemoryUtilization"
  statistic   = "Average"
  period      = 60

  dimensions = {
    ClusterName = var.ecs_cluster_name
    ServiceName = var.ecs_service_name
  }

  alarm_actions = [aws_sns_topic.alerts.arn]
}

resource "aws_cloudwatch_metric_alarm" "alb_5xx_rate" {
  alarm_name          = "${var.name_prefix}-alb-5xx-rate"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 5
  datapoints_to_alarm = 5
  threshold           = 1

  treat_missing_data = "notBreaching"

  metric_query {
    id = "m1"

    metric {
      namespace   = "AWS/ApplicationELB"
      metric_name = "HTTPCode_Target_5XX_Count"
      period      = 60
      stat        = "Sum"

      dimensions = {
        LoadBalancer = var.alb_arn_suffix
      }
    }
  }

  metric_query {
    id = "m2"

    metric {
      namespace   = "AWS/ApplicationELB"
      metric_name = "RequestCount"
      period      = 60
      stat        = "Sum"

      dimensions = {
        LoadBalancer = var.alb_arn_suffix
      }
    }
  }

  metric_query {
    id          = "e1"
    expression  = "100 * (m1 / m2)"
    label       = "5xx error rate"
    return_data = true
  }

  alarm_actions = [aws_sns_topic.alerts.arn]
}

resource "aws_cloudwatch_metric_alarm" "alb_unhealthy_hosts" {
  alarm_name          = "${var.name_prefix}-alb-unhealthy-hosts"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  datapoints_to_alarm = 2
  threshold           = 0

  namespace   = "AWS/ApplicationELB"
  metric_name = "UnHealthyHostCount"
  statistic   = "Average"
  period      = 60

  dimensions = {
    TargetGroup  = var.target_group_arn_suffix
    LoadBalancer = var.alb_arn_suffix
  }

  alarm_actions = [aws_sns_topic.alerts.arn]
}

# ECS autoscaling target
resource "aws_appautoscaling_target" "ecs" {
  service_namespace  = "ecs"
  scalable_dimension = "ecs:service:DesiredCount"

  resource_id = "service/${var.ecs_cluster_name}/${var.ecs_service_name}"

  min_capacity = var.min_capacity
  max_capacity = var.max_capacity
}

# ECS CPU autoscaling policy
resource "aws_appautoscaling_policy" "ecs_cpu" {
  name        = "${var.name_prefix}-ecs-cpu-scaling"
  policy_type = "TargetTrackingScaling"

  resource_id        = aws_appautoscaling_target.ecs.resource_id
  scalable_dimension = aws_appautoscaling_target.ecs.scalable_dimension
  service_namespace  = aws_appautoscaling_target.ecs.service_namespace

  target_tracking_scaling_policy_configuration {
    target_value = var.cpu_target_value

    scale_in_cooldown  = var.scale_in_cooldown
    scale_out_cooldown = var.scale_out_cooldown

    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageCPUUtilization"
    }
  }
}