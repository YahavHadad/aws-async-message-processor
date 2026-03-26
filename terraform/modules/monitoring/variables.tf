variable "name" {
  description = "Resource name prefix"
  type        = string
}

variable "aws_region" {
  type = string
}

# ── Alert destination ───────────────────────────────────────────
variable "alert_email" {
  description = "Email address for CloudWatch alarm notifications"
  type        = string
}

# ── ECS ─────────────────────────────────────────────────────────
variable "ecs_cluster_name" {
  type = string
}

variable "producer_service_name" {
  type = string
}

variable "consumer_service_name" {
  type = string
}

# ── SQS ─────────────────────────────────────────────────────────
variable "sqs_queue_name" {
  type = string
}

variable "dlq_name" {
  type = string
}

# ── CLB ─────────────────────────────────────────────────────────
variable "clb_name" {
  type = string
}
