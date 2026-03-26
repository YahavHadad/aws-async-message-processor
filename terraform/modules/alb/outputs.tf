output "clb_dns_name" {
  description = "DNS name of the Classic Load Balancer"
  value       = aws_elb.this.dns_name
}

output "clb_name" {
  description = "Name of the CLB (used by ECS service load_balancer block)"
  value       = aws_elb.this.name
}
