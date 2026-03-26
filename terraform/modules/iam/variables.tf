variable "name" {
  description = "Resource name prefix"
  type        = string
}

variable "aws_region" {
  type = string
}

variable "account_id" {
  type = string
}

variable "ecr_producer_arn" {
  type = string
}

variable "ecr_consumer_arn" {
  type = string
}

variable "ssm_parameter_arn" {
  type = string
}

variable "execution_ssm_parameter_arns" {
  description = "SSM parameter ARNs the ECS execution role can read for env/secrets injection"
  type        = list(string)
}

variable "sqs_queue_arn" {
  type = string
}

variable "s3_bucket_arn" {
  type = string
}

variable "log_group_prefix" {
  description = "CloudWatch log group name prefix (e.g. /ecs/myapp) for scoped permissions"
  type        = string
}

variable "ecs_cluster_name" {
  description = "Name of the ECS cluster (for scoping EC2 instance role permissions)"
  type        = string
}

variable "s3_key_prefix" {
  description = "S3 key prefix the consumer writes to (e.g. messages)"
  type        = string
  default     = "messages"
}
