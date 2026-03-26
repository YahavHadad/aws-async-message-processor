variable "name" {
  description = "Resource name prefix"
  type        = string
}

variable "public_subnet_ids" {
  type = list(string)
}

variable "lb_security_group_id" {
  description = "Security group to attach to the CLB"
  type        = string
}

variable "container_port" {
  description = "Port the producer container listens on (fixed host port)"
  type        = number
}
