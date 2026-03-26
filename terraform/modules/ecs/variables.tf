variable "name" {
  description = "Resource name prefix"
  type        = string
}

variable "aws_region" {
  type = string
}

# ── Networking ──────────────────────────────────────────────────
variable "public_subnet_ids" {
  type = list(string)
}

variable "ecs_security_group_id" {
  type = string
}

# ── IAM ─────────────────────────────────────────────────────────
variable "execution_role_arn" {
  type = string
}

variable "producer_task_role_arn" {
  type = string
}

variable "consumer_task_role_arn" {
  type = string
}

variable "ecs_instance_profile_arn" {
  description = "IAM instance profile ARN for ECS EC2 container instances"
  type        = string
}

# ── EC2 / ASG ───────────────────────────────────────────────────
variable "instance_type" {
  description = "EC2 instance type for ECS container instances"
  type        = string
  default     = "t2.micro"
}

variable "asg_min_size" {
  type    = number
  default = 1
}

variable "asg_max_size" {
  type    = number
  default = 1
}

variable "asg_desired_capacity" {
  type    = number
  default = 1
}

# ── Container images ────────────────────────────────────────────
variable "producer_image" {
  description = "Full ECR image URI including tag"
  type        = string
}

variable "consumer_image" {
  description = "Full ECR image URI including tag"
  type        = string
}

# ── Container sizing (applied at container level for EC2 launch type) ─
variable "producer_cpu" {
  description = "CPU units for producer container"
  type        = number
  default     = 128
}

variable "producer_memory" {
  description = "Hard memory limit (MiB) for producer container"
  type        = number
  default     = 384
}

variable "consumer_cpu" {
  description = "CPU units for consumer container"
  type        = number
  default     = 128
}

variable "consumer_memory" {
  description = "Hard memory limit (MiB) for consumer container"
  type        = number
  default     = 384
}

variable "producer_container_port" {
  type    = number
  default = 8000
}

variable "producer_desired_count" {
  type    = number
  default = 1
}

variable "consumer_desired_count" {
  type    = number
  default = 1
}

# ── Downstream resources (env vars injected into containers) ────
variable "ssm_parameter_name" {
  type = string
}

variable "producer_sqs_queue_url_ssm_arn" {
  description = "SSM parameter ARN for producer SQS queue URL runtime config"
  type        = string
}

variable "consumer_sqs_queue_url_ssm_arn" {
  description = "SSM parameter ARN for consumer SQS queue URL runtime config"
  type        = string
}

variable "consumer_s3_bucket_name_ssm_arn" {
  description = "SSM parameter ARN for consumer S3 bucket name runtime config"
  type        = string
}

variable "consumer_sqs_wait_time_seconds_ssm_arn" {
  description = "SSM parameter ARN for consumer SQS wait time runtime config"
  type        = string
}

variable "consumer_sqs_max_messages_ssm_arn" {
  description = "SSM parameter ARN for consumer SQS max messages runtime config"
  type        = string
}

# ── CLB integration ─────────────────────────────────────────────
variable "clb_name" {
  description = "Name of the Classic Load Balancer for the producer service"
  type        = string
}

# ── SQS queue name (for autoscaling metric) ─────────────────────
variable "sqs_queue_name" {
  type = string
}

# ── Scaling limits ──────────────────────────────────────────────
variable "producer_max_count" {
  type    = number
  default = 2
}

variable "consumer_max_count" {
  type    = number
  default = 2
}

# ── Observability ───────────────────────────────────────────────
variable "log_retention_days" {
  type    = number
  default = 7
}

variable "enable_container_insights" {
  type    = bool
  default = false
}
