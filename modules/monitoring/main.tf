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