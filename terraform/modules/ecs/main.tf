# ── CloudWatch Log Groups ───────────────────────────────────────

resource "aws_cloudwatch_log_group" "producer" {
  name              = "/ecs/${var.name}/producer"
  retention_in_days = var.log_retention_days

  tags = { Name = "${var.name}-producer-logs" }
}

resource "aws_cloudwatch_log_group" "consumer" {
  name              = "/ecs/${var.name}/consumer"
  retention_in_days = var.log_retention_days

  tags = { Name = "${var.name}-consumer-logs" }
}

# ── ECS Cluster ─────────────────────────────────────────────────

resource "aws_ecs_cluster" "this" {
  name = "${var.name}-cluster"

  setting {
    name  = "containerInsights"
    value = var.enable_container_insights ? "enabled" : "disabled"
  }

  tags = { Name = "${var.name}-cluster" }
}

# ── EC2 Instances (ECS Container Instances) ─────────────────────

data "aws_ssm_parameter" "ecs_ami" {
  name = "/aws/service/ecs/optimized-ami/amazon-linux-2/recommended/image_id"
}

resource "aws_launch_template" "ecs" {
  name_prefix   = "${var.name}-ecs-"
  image_id      = data.aws_ssm_parameter.ecs_ami.value
  instance_type = var.instance_type

  iam_instance_profile {
    arn = var.ecs_instance_profile_arn
  }

  network_interfaces {
    associate_public_ip_address = true
    security_groups             = [var.ecs_security_group_id]
  }

  user_data = base64encode(<<-EOF
    #!/bin/bash
    echo ECS_CLUSTER=${aws_ecs_cluster.this.name} >> /etc/ecs/ecs.config
  EOF
  )

  tag_specifications {
    resource_type = "instance"
    tags          = { Name = "${var.name}-ecs-instance" }
  }

  lifecycle {
    create_before_destroy = true
  }

  tags = { Name = "${var.name}-ecs-lt" }
}

resource "aws_autoscaling_group" "ecs" {
  name                = "${var.name}-ecs-asg"
  min_size            = var.asg_min_size
  max_size            = var.asg_max_size
  desired_capacity    = var.asg_desired_capacity
  vpc_zone_identifier = var.public_subnet_ids

  launch_template {
    id      = aws_launch_template.ecs.id
    version = "$Latest"
  }

  tag {
    key                 = "Name"
    value               = "${var.name}-ecs-instance"
    propagate_at_launch = true
  }

  tag {
    key                 = "AmazonECSManaged"
    value               = "true"
    propagate_at_launch = true
  }

  lifecycle {
    ignore_changes = [desired_capacity]
  }
}

# ── Producer Task Definition ────────────────────────────────────

resource "aws_ecs_task_definition" "producer" {
  family                   = "${var.name}-producer"
  network_mode             = "bridge"
  requires_compatibilities = ["EC2"]
  execution_role_arn       = var.execution_role_arn
  task_role_arn            = var.producer_task_role_arn

  container_definitions = jsonencode([{
    name      = "producer"
    image     = var.producer_image
    cpu       = var.producer_cpu
    memory    = var.producer_memory
    essential = true

    portMappings = [{
      containerPort = var.producer_container_port
      hostPort      = var.producer_container_port
      protocol      = "tcp"
    }]

    environment = [
      { name = "AWS_REGION", value = var.aws_region },
      { name = "SSM_TOKEN_NAME", value = var.ssm_parameter_name },
      { name = "PORT", value = tostring(var.producer_container_port) }
    ]

    secrets = [
      { name = "SQS_QUEUE_URL", valueFrom = var.producer_sqs_queue_url_ssm_arn }
    ]

    logConfiguration = {
      logDriver = "awslogs"
      options = {
        "awslogs-group"         = aws_cloudwatch_log_group.producer.name
        "awslogs-region"        = var.aws_region
        "awslogs-stream-prefix" = "producer"
      }
    }

    healthCheck = {
      command     = ["CMD-SHELL", "python -c \"import urllib.request; urllib.request.urlopen('http://localhost:${var.producer_container_port}/health')\""]
      interval    = 30
      timeout     = 5
      retries     = 3
      startPeriod = 10
    }
  }])

  tags = { Name = "${var.name}-producer-td" }
}

# ── Producer Service ────────────────────────────────────────────

resource "aws_ecs_service" "producer" {
  name            = "${var.name}-producer-svc"
  cluster         = aws_ecs_cluster.this.id
  task_definition = aws_ecs_task_definition.producer.arn
  desired_count   = var.producer_desired_count
  launch_type     = "EC2"
  deployment_minimum_healthy_percent = 0
  deployment_maximum_percent         = 100

  load_balancer {
    elb_name       = var.clb_name
    container_name = "producer"
    container_port = var.producer_container_port
  }

  lifecycle {
    ignore_changes = [desired_count, task_definition]
  }

  depends_on = [aws_autoscaling_group.ecs]

  tags = { Name = "${var.name}-producer-svc" }
}

# ── Consumer Task Definition ────────────────────────────────────

resource "aws_ecs_task_definition" "consumer" {
  family                   = "${var.name}-consumer"
  network_mode             = "bridge"
  requires_compatibilities = ["EC2"]
  execution_role_arn       = var.execution_role_arn
  task_role_arn            = var.consumer_task_role_arn

  container_definitions = jsonencode([{
    name      = "consumer"
    image     = var.consumer_image
    cpu       = var.consumer_cpu
    memory    = var.consumer_memory
    essential = true

    environment = [
      { name = "AWS_REGION", value = var.aws_region }
    ]

    secrets = [
      { name = "SQS_QUEUE_URL", valueFrom = var.consumer_sqs_queue_url_ssm_arn },
      { name = "S3_BUCKET_NAME", valueFrom = var.consumer_s3_bucket_name_ssm_arn },
      { name = "SQS_WAIT_TIME_SECONDS", valueFrom = var.consumer_sqs_wait_time_seconds_ssm_arn },
      { name = "SQS_MAX_MESSAGES", valueFrom = var.consumer_sqs_max_messages_ssm_arn }
    ]

    logConfiguration = {
      logDriver = "awslogs"
      options = {
        "awslogs-group"         = aws_cloudwatch_log_group.consumer.name
        "awslogs-region"        = var.aws_region
        "awslogs-stream-prefix" = "consumer"
      }
    }
  }])

  tags = { Name = "${var.name}-consumer-td" }
}

# ── Consumer Service ────────────────────────────────────────────

resource "aws_ecs_service" "consumer" {
  name            = "${var.name}-consumer-svc"
  cluster         = aws_ecs_cluster.this.id
  task_definition = aws_ecs_task_definition.consumer.arn
  desired_count   = var.consumer_desired_count
  launch_type     = "EC2"
  deployment_minimum_healthy_percent = 0
  deployment_maximum_percent         = 100

  lifecycle {
    ignore_changes = [desired_count, task_definition]
  }

  depends_on = [aws_autoscaling_group.ecs]

  tags = { Name = "${var.name}-consumer-svc" }
}

# ================================================================
#  Auto Scaling
# ================================================================

# ── Producer: CPU-based scaling ─────────────────────────────────

resource "aws_appautoscaling_target" "producer" {
  max_capacity       = var.producer_max_count
  min_capacity       = 1
  resource_id        = "service/${aws_ecs_cluster.this.name}/${aws_ecs_service.producer.name}"
  scalable_dimension = "ecs:service:DesiredCount"
  service_namespace  = "ecs"
}

resource "aws_appautoscaling_policy" "producer_cpu" {
  name               = "${var.name}-producer-cpu-scaling"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.producer.resource_id
  scalable_dimension = aws_appautoscaling_target.producer.scalable_dimension
  service_namespace  = aws_appautoscaling_target.producer.service_namespace

  target_tracking_scaling_policy_configuration {
    target_value       = 70
    scale_in_cooldown  = 300
    scale_out_cooldown = 60

    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageCPUUtilization"
    }
  }
}

# ── Consumer: SQS Queue Depth ──────────────────────────────────

resource "aws_appautoscaling_target" "consumer" {
  max_capacity       = var.consumer_max_count
  min_capacity       = 1
  resource_id        = "service/${aws_ecs_cluster.this.name}/${aws_ecs_service.consumer.name}"
  scalable_dimension = "ecs:service:DesiredCount"
  service_namespace  = "ecs"
}

resource "aws_appautoscaling_policy" "consumer_queue_depth" {
  name               = "${var.name}-consumer-queue-scaling"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.consumer.resource_id
  scalable_dimension = aws_appautoscaling_target.consumer.scalable_dimension
  service_namespace  = aws_appautoscaling_target.consumer.service_namespace

  target_tracking_scaling_policy_configuration {
    target_value       = 5
    scale_in_cooldown  = 300
    scale_out_cooldown = 60

    customized_metric_specification {
      metric_name = "ApproximateNumberOfMessagesVisible"
      namespace   = "AWS/SQS"
      statistic   = "Average"

      dimensions {
        name  = "QueueName"
        value = var.sqs_queue_name
      }
    }
  }
}
