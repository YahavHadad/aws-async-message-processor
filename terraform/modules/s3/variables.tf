variable "name" {
  description = "Resource name prefix"
  type        = string
}

variable "account_id" {
  description = "AWS account ID (used to ensure bucket name uniqueness)"
  type        = string
}
