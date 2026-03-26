variable "aws_region" {
  description = "AWS region for the state resources"
  type        = string
  default     = "eu-west-1"
}

variable "project_name" {
  description = "Project name prefix (must match the value used in env configs)"
  type        = string
  default     = "async-msg-proc"
}
