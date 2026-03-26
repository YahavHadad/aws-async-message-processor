resource "aws_ssm_parameter" "validation_token" {
  name        = "/${var.project_name}/${var.environment}/validation-token"
  description = "Secret token for producer request validation"
  type        = "SecureString"
  value       = var.validation_token

  tags = { Name = "${var.name}-validation-token" }
}

resource "aws_ssm_parameter" "producer_sqs_queue_url" {
  name        = "/${var.project_name}/${var.environment}/producer/sqs-queue-url"
  description = "Producer runtime config: SQS queue URL"
  type        = "String"
  value       = var.producer_sqs_queue_url

  lifecycle {
    ignore_changes = [value]
  }

  tags = { Name = "${var.name}-producer-sqs-queue-url" }
}

resource "aws_ssm_parameter" "consumer_sqs_queue_url" {
  name        = "/${var.project_name}/${var.environment}/consumer/sqs-queue-url"
  description = "Consumer runtime config: SQS queue URL"
  type        = "String"
  value       = var.consumer_sqs_queue_url

  lifecycle {
    ignore_changes = [value]
  }

  tags = { Name = "${var.name}-consumer-sqs-queue-url" }
}

resource "aws_ssm_parameter" "consumer_s3_bucket_name" {
  name        = "/${var.project_name}/${var.environment}/consumer/s3-bucket-name"
  description = "Consumer runtime config: S3 bucket name"
  type        = "String"
  value       = var.consumer_s3_bucket_name

  lifecycle {
    ignore_changes = [value]
  }

  tags = { Name = "${var.name}-consumer-s3-bucket-name" }
}

resource "aws_ssm_parameter" "consumer_sqs_wait_time_seconds" {
  name        = "/${var.project_name}/${var.environment}/consumer/sqs-wait-time-seconds"
  description = "Consumer runtime config: SQS wait time seconds"
  type        = "String"
  value       = tostring(var.consumer_sqs_wait_time_seconds)

  lifecycle {
    ignore_changes = [value]
  }

  tags = { Name = "${var.name}-consumer-sqs-wait-time-seconds" }
}

resource "aws_ssm_parameter" "consumer_sqs_max_messages" {
  name        = "/${var.project_name}/${var.environment}/consumer/sqs-max-messages"
  description = "Consumer runtime config: SQS max messages"
  type        = "String"
  value       = tostring(var.consumer_sqs_max_messages)

  lifecycle {
    ignore_changes = [value]
  }

  tags = { Name = "${var.name}-consumer-sqs-max-messages" }
}
