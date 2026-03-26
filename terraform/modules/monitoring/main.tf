# ================================================================
#  SNS Topic – alert destination
# ================================================================

resource "aws_sns_topic" "alerts" {
  name = "${var.name}-alerts"
  tags = { Name = "${var.name}-alerts" }
}

resource "aws_sns_topic_subscription" "email" {
  topic_arn = aws_sns_topic.alerts.arn
  protocol  = "email"
  endpoint  = var.alert_email
}

# ================================================================
#  CloudWatch Dashboard (Free Tier: 3 dashboards, 50 metrics each)
# ================================================================

resource "aws_cloudwatch_dashboard" "main" {
  dashboard_name = "${var.name}-overview"

  dashboard_body = jsonencode({
    widgets = [
      # ── Row 1: ECS CPU & Memory ──────────────────────────────
      {
        type   = "metric"
        x      = 0
        y      = 0
        width  = 12
        height = 6
        properties = {
          title  = "ECS – CPU Utilization (%)"
          region = var.aws_region
          stat   = "Average"
          period = 300
          view   = "timeSeries"
          metrics = [
            ["AWS/ECS", "CPUUtilization", "ClusterName", var.ecs_cluster_name, "ServiceName", var.producer_service_name, { label = "Producer" }],
            ["AWS/ECS", "CPUUtilization", "ClusterName", var.ecs_cluster_name, "ServiceName", var.consumer_service_name, { label = "Consumer" }]
          ]
        }
      },
      {
        type   = "metric"
        x      = 12
        y      = 0
        width  = 12
        height = 6
        properties = {
          title  = "ECS – Memory Utilization (%)"
          region = var.aws_region
          stat   = "Average"
          period = 300
          view   = "timeSeries"
          metrics = [
            ["AWS/ECS", "MemoryUtilization", "ClusterName", var.ecs_cluster_name, "ServiceName", var.producer_service_name, { label = "Producer" }],
            ["AWS/ECS", "MemoryUtilization", "ClusterName", var.ecs_cluster_name, "ServiceName", var.consumer_service_name, { label = "Consumer" }]
          ]
        }
      },

      # ── Row 2: SQS Queue Health ──────────────────────────────
      {
        type   = "metric"
        x      = 0
        y      = 6
        width  = 8
        height = 6
        properties = {
          title  = "SQS – Messages Visible"
          region = var.aws_region
          stat   = "Average"
          period = 60
          view   = "timeSeries"
          metrics = [
            ["AWS/SQS", "ApproximateNumberOfMessagesVisible", "QueueName", var.sqs_queue_name, { label = "Main Queue" }],
            ["AWS/SQS", "ApproximateNumberOfMessagesVisible", "QueueName", var.dlq_name, { label = "DLQ", color = "#d62728" }]
          ]
        }
      },
      {
        type   = "metric"
        x      = 8
        y      = 6
        width  = 8
        height = 6
        properties = {
          title  = "SQS – Age of Oldest Message (s)"
          region = var.aws_region
          stat   = "Maximum"
          period = 60
          view   = "timeSeries"
          metrics = [
            ["AWS/SQS", "ApproximateAgeOfOldestMessage", "QueueName", var.sqs_queue_name, { label = "Main Queue" }]
          ]
        }
      },
      {
        type   = "metric"
        x      = 16
        y      = 6
        width  = 8
        height = 6
        properties = {
          title  = "SQS – Throughput (msgs/min)"
          region = var.aws_region
          stat   = "Sum"
          period = 60
          view   = "timeSeries"
          metrics = [
            ["AWS/SQS", "NumberOfMessagesSent", "QueueName", var.sqs_queue_name, { label = "Sent" }],
            ["AWS/SQS", "NumberOfMessagesReceived", "QueueName", var.sqs_queue_name, { label = "Received" }],
            ["AWS/SQS", "NumberOfMessagesDeleted", "QueueName", var.sqs_queue_name, { label = "Deleted" }]
          ]
        }
      },

      # ── Row 3: CLB Health & Latency ──────────────────────────
      {
        type   = "metric"
        x      = 0
        y      = 12
        width  = 12
        height = 6
        properties = {
          title  = "CLB – Request Count & Latency"
          region = var.aws_region
          period = 60
          view   = "timeSeries"
          metrics = [
            ["AWS/ELB", "RequestCount", "LoadBalancerName", var.clb_name, { stat = "Sum", label = "Requests" }],
            ["AWS/ELB", "Latency", "LoadBalancerName", var.clb_name, { stat = "Average", label = "Avg Latency (s)", yAxis = "right" }]
          ]
        }
      },
      {
        type   = "metric"
        x      = 12
        y      = 12
        width  = 12
        height = 6
        properties = {
          title  = "CLB – Host Health"
          region = var.aws_region
          stat   = "Average"
          period = 60
          view   = "timeSeries"
          metrics = [
            ["AWS/ELB", "HealthyHostCount", "LoadBalancerName", var.clb_name, { label = "Healthy", color = "#2ca02c" }],
            ["AWS/ELB", "UnHealthyHostCount", "LoadBalancerName", var.clb_name, { label = "Unhealthy", color = "#d62728" }]
          ]
        }
      }
    ]
  })
}

# ================================================================
#  CloudWatch Alarms (Free Tier: 10 alarms)
# ================================================================

# ── DLQ has messages → consumer failures ────────────────────────
resource "aws_cloudwatch_metric_alarm" "dlq_messages" {
  alarm_name          = "${var.name}-dlq-has-messages"
  alarm_description   = "Messages appeared in the DLQ — consumer is failing to process."
  namespace           = "AWS/SQS"
  metric_name         = "ApproximateNumberOfMessagesVisible"
  statistic           = "Sum"
  period              = 300
  evaluation_periods  = 1
  threshold           = 0
  comparison_operator = "GreaterThanThreshold"
  treat_missing_data  = "notBreaching"

  dimensions = {
    QueueName = var.dlq_name
  }

  alarm_actions = [aws_sns_topic.alerts.arn]
  ok_actions    = [aws_sns_topic.alerts.arn]

  tags = { Name = "${var.name}-dlq-alarm" }
}

# ── SQS main queue backlog ─────────────────────────────────────
resource "aws_cloudwatch_metric_alarm" "sqs_backlog" {
  alarm_name          = "${var.name}-sqs-backlog"
  alarm_description   = "SQS queue has > 100 messages waiting — consumer may be falling behind."
  namespace           = "AWS/SQS"
  metric_name         = "ApproximateNumberOfMessagesVisible"
  statistic           = "Average"
  period              = 300
  evaluation_periods  = 2
  threshold           = 100
  comparison_operator = "GreaterThanThreshold"
  treat_missing_data  = "notBreaching"

  dimensions = {
    QueueName = var.sqs_queue_name
  }

  alarm_actions = [aws_sns_topic.alerts.arn]
  ok_actions    = [aws_sns_topic.alerts.arn]

  tags = { Name = "${var.name}-sqs-backlog-alarm" }
}

# ── SQS oldest message too old ─────────────────────────────────
resource "aws_cloudwatch_metric_alarm" "sqs_age" {
  alarm_name          = "${var.name}-sqs-oldest-message-age"
  alarm_description   = "Oldest SQS message is > 5 min old — processing is stalled."
  namespace           = "AWS/SQS"
  metric_name         = "ApproximateAgeOfOldestMessage"
  statistic           = "Maximum"
  period              = 300
  evaluation_periods  = 1
  threshold           = 300
  comparison_operator = "GreaterThanThreshold"
  treat_missing_data  = "notBreaching"

  dimensions = {
    QueueName = var.sqs_queue_name
  }

  alarm_actions = [aws_sns_topic.alerts.arn]
  ok_actions    = [aws_sns_topic.alerts.arn]

  tags = { Name = "${var.name}-sqs-age-alarm" }
}

# ── Producer service down (no CPU data → no running tasks) ─────
resource "aws_cloudwatch_metric_alarm" "producer_down" {
  alarm_name          = "${var.name}-producer-no-tasks"
  alarm_description   = "Producer service has no running tasks."
  namespace           = "AWS/ECS"
  metric_name         = "CPUUtilization"
  statistic           = "Average"
  period              = 300
  evaluation_periods  = 1
  threshold           = 0
  comparison_operator = "LessThanOrEqualToThreshold"
  treat_missing_data  = "breaching"

  dimensions = {
    ClusterName = var.ecs_cluster_name
    ServiceName = var.producer_service_name
  }

  alarm_actions = [aws_sns_topic.alerts.arn]
  ok_actions    = [aws_sns_topic.alerts.arn]

  tags = { Name = "${var.name}-producer-down-alarm" }
}

# ── Consumer service down (no CPU data → no running tasks) ─────
resource "aws_cloudwatch_metric_alarm" "consumer_down" {
  alarm_name          = "${var.name}-consumer-no-tasks"
  alarm_description   = "Consumer service has no running tasks."
  namespace           = "AWS/ECS"
  metric_name         = "CPUUtilization"
  statistic           = "Average"
  period              = 300
  evaluation_periods  = 1
  threshold           = 0
  comparison_operator = "LessThanOrEqualToThreshold"
  treat_missing_data  = "breaching"

  dimensions = {
    ClusterName = var.ecs_cluster_name
    ServiceName = var.consumer_service_name
  }

  alarm_actions = [aws_sns_topic.alerts.arn]
  ok_actions    = [aws_sns_topic.alerts.arn]

  tags = { Name = "${var.name}-consumer-down-alarm" }
}
