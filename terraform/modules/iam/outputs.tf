output "ecs_task_execution_role_arn" {
  value = aws_iam_role.ecs_task_execution.arn
}

output "producer_task_role_arn" {
  value = aws_iam_role.producer_task.arn
}

output "consumer_task_role_arn" {
  value = aws_iam_role.consumer_task.arn
}

output "ecs_instance_profile_arn" {
  description = "IAM instance profile ARN for ECS EC2 container instances"
  value       = aws_iam_instance_profile.ecs_ec2.arn
}
