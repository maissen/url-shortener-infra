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