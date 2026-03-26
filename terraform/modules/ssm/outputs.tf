output "parameter_name" {
  value = aws_ssm_parameter.validation_token.name
}

output "parameter_arn" {
  value = aws_ssm_parameter.validation_token.arn
}

output "producer_sqs_queue_url_arn" {
  value = aws_ssm_parameter.producer_sqs_queue_url.arn
}

output "consumer_sqs_queue_url_arn" {
  value = aws_ssm_parameter.consumer_sqs_queue_url.arn
}

output "consumer_s3_bucket_name_arn" {
  value = aws_ssm_parameter.consumer_s3_bucket_name.arn
}

output "consumer_sqs_wait_time_seconds_arn" {
  value = aws_ssm_parameter.consumer_sqs_wait_time_seconds.arn
}

output "consumer_sqs_max_messages_arn" {
  value = aws_ssm_parameter.consumer_sqs_max_messages.arn
}
