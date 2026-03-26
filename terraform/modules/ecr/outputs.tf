output "producer_repository_url" {
  value = aws_ecr_repository.producer.repository_url
}

output "producer_repository_arn" {
  value = aws_ecr_repository.producer.arn
}

output "consumer_repository_url" {
  value = aws_ecr_repository.consumer.repository_url
}

output "consumer_repository_arn" {
  value = aws_ecr_repository.consumer.arn
}
