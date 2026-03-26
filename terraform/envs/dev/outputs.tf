output "clb_dns_name" {
  description = "DNS name of the Classic Load Balancer"
  value       = module.lb.clb_dns_name
}

output "sqs_queue_url" {
  value = module.sqs.queue_url
}

output "s3_bucket_name" {
  value = module.s3.bucket_id
}

output "ecr_producer_repo_url" {
  value = module.ecr.producer_repository_url
}

output "ecr_consumer_repo_url" {
  value = module.ecr.consumer_repository_url
}

output "ecs_cluster_name" {
  value = module.ecs.cluster_name
}

output "producer_service_name" {
  value = module.ecs.producer_service_name
}

output "consumer_service_name" {
  value = module.ecs.consumer_service_name
}

output "sns_topic_arn" {
  description = "SNS topic ARN for alerts (use as GitHub secret SNS_TOPIC_ARN)"
  value       = module.monitoring.sns_topic_arn
}

output "cloudwatch_dashboard_url" {
  description = "Direct link to the CloudWatch dashboard"
  value       = "https://${var.aws_region}.console.aws.amazon.com/cloudwatch/home?region=${var.aws_region}#dashboards:name=${module.monitoring.dashboard_name}"
}
