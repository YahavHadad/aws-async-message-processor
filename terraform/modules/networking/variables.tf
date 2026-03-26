variable "name" {
  description = "Resource name prefix"
  type        = string
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
}

variable "public_subnet_cidrs" {
  description = "CIDR blocks for public subnets"
  type        = list(string)
}

variable "availability_zones" {
  description = "AZs for the public subnets"
  type        = list(string)
}

variable "producer_container_port" {
  description = "Container port used by the producer (for SG ingress rule)"
  type        = number
}
