# ================================================================
#  ECS Task Execution Role
# ================================================================
resource "aws_iam_role" "ecs_task_execution" {
  name = "${var.name}-ecs-exec-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ecs-tasks.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy" "ecs_exec" {
  name = "${var.name}-ecs-exec-policy"
  role = aws_iam_role.ecs_task_execution.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "ECRAuth"
        Effect   = "Allow"
        Action   = ["ecr:GetAuthorizationToken"]
        Resource = "*"
      },
      {
        Sid    = "ECRPull"
        Effect = "Allow"
        Action = [
          "ecr:BatchCheckLayerAvailability",
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage"
        ]
        Resource = [var.ecr_producer_arn, var.ecr_consumer_arn]
      },
      {
        Sid    = "CloudWatchLogs"
        Effect = "Allow"
        Action = ["logs:CreateLogStream", "logs:PutLogEvents"]
        Resource = [
          "arn:aws:logs:${var.aws_region}:${var.account_id}:log-group:${var.log_group_prefix}/producer:*",
          "arn:aws:logs:${var.aws_region}:${var.account_id}:log-group:${var.log_group_prefix}/consumer:*"
        ]
      },
      {
        Sid      = "SSMReadForEcsSecrets"
        Effect   = "Allow"
        Action   = ["ssm:GetParameter", "ssm:GetParameters"]
        Resource = var.execution_ssm_parameter_arns
      }
    ]
  })
}

# ================================================================
#  Producer Task Role
# ================================================================
resource "aws_iam_role" "producer_task" {
  name = "${var.name}-producer-task-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ecs-tasks.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy" "producer_task" {
  name = "${var.name}-producer-task-policy"
  role = aws_iam_role.producer_task.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "SQSSend"
        Effect   = "Allow"
        Action   = ["sqs:SendMessage"]
        Resource = var.sqs_queue_arn
      },
      {
        Sid      = "SSMRead"
        Effect   = "Allow"
        Action   = ["ssm:GetParameter"]
        Resource = var.ssm_parameter_arn
      }
    ]
  })
}

# ================================================================
#  Consumer Task Role
# ================================================================
resource "aws_iam_role" "consumer_task" {
  name = "${var.name}-consumer-task-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ecs-tasks.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy" "consumer_task" {
  name = "${var.name}-consumer-task-policy"
  role = aws_iam_role.consumer_task.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "SQSConsume"
        Effect = "Allow"
        Action = [
          "sqs:ReceiveMessage",
          "sqs:DeleteMessage"
        ]
        Resource = var.sqs_queue_arn
      },
      {
        Sid      = "S3Upload"
        Effect   = "Allow"
        Action   = ["s3:PutObject"]
        Resource = "${var.s3_bucket_arn}/${var.s3_key_prefix}/*"
      }
    ]
  })
}

# ================================================================
#  ECS EC2 Instance Role (container-instance registration)
# ================================================================
resource "aws_iam_role" "ecs_ec2_instance" {
  name = "${var.name}-ecs-ec2-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy" "ecs_ec2_instance" {
  name = "${var.name}-ecs-ec2-policy"
  role = aws_iam_role.ecs_ec2_instance.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "ECSClusterActions"
        Effect = "Allow"
        Action = [
          "ecs:RegisterContainerInstance",
          "ecs:DeregisterContainerInstance",
          "ecs:SubmitTaskStateChange",
          "ecs:SubmitContainerStateChange",
          "ecs:SubmitAttachmentStateChanges"
        ]
        Resource = "arn:aws:ecs:${var.aws_region}:${var.account_id}:cluster/${var.ecs_cluster_name}"
      },
      {
        Sid    = "ECSContainerInstanceActions"
        Effect = "Allow"
        Action = [
          "ecs:Poll",
          "ecs:StartTelemetrySession",
          "ecs:UpdateContainerInstancesState"
        ]
        Resource = "arn:aws:ecs:${var.aws_region}:${var.account_id}:container-instance/${var.ecs_cluster_name}/*"
      },
      {
        Sid      = "ECSDiscoverEndpoint"
        Effect   = "Allow"
        Action   = ["ecs:DiscoverPollEndpoint"]
        Resource = "*"
      },
      {
        Sid      = "ECRAuth"
        Effect   = "Allow"
        Action   = ["ecr:GetAuthorizationToken"]
        Resource = "*"
      },
      {
        Sid    = "ECRPull"
        Effect = "Allow"
        Action = [
          "ecr:BatchCheckLayerAvailability",
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage"
        ]
        Resource = [var.ecr_producer_arn, var.ecr_consumer_arn]
      },
      {
        Sid    = "CloudWatchLogs"
        Effect = "Allow"
        Action = ["logs:CreateLogStream", "logs:PutLogEvents"]
        Resource = [
          "arn:aws:logs:${var.aws_region}:${var.account_id}:log-group:${var.log_group_prefix}/producer:*",
          "arn:aws:logs:${var.aws_region}:${var.account_id}:log-group:${var.log_group_prefix}/consumer:*"
        ]
      }
    ]
  })
}

resource "aws_iam_instance_profile" "ecs_ec2" {
  name = "${var.name}-ecs-ec2-profile"
  role = aws_iam_role.ecs_ec2_instance.name
}
