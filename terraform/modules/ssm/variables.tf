variable "name" {
  description = "Resource name prefix (used in parameter path)"
  type        = string
}

variable "project_name" {
  description = "Project name (used in SSM path)"
  type        = string
}

variable "environment" {
  description = "Deployment environment (used in SSM path)"
  type        = string
}

variable "validation_token" {
  description = "Secret token value"
  type        = string
  sensitive   = true
}

variable "producer_sqs_queue_url" {
  description = "Initial producer SQS queue URL value"
  type        = string
}

variable "consumer_sqs_queue_url" {
  description = "Initial consumer SQS queue URL value"
  type        = string
}

variable "consumer_s3_bucket_name" {
  description = "Initial consumer S3 bucket name value"
  type        = string
}

variable "consumer_sqs_wait_time_seconds" {
  description = "Initial consumer SQS wait time seconds"
  type        = number
  default     = 20
}

variable "consumer_sqs_max_messages" {
  description = "Initial consumer SQS max messages per poll"
  type        = number
  default     = 10
}
