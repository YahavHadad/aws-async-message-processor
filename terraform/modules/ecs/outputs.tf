output "cluster_name" {
  value = aws_ecs_cluster.this.name
}

output "producer_service_name" {
  value = aws_ecs_service.producer.name
}

output "consumer_service_name" {
  value = aws_ecs_service.consumer.name
}
