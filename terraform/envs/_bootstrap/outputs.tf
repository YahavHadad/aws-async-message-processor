output "state_bucket_name" {
  description = "S3 bucket name for Terraform remote state"
  value       = aws_s3_bucket.state.id
}

output "lock_table_name" {
  description = "DynamoDB table name for state locking"
  value       = aws_dynamodb_table.tf_locks.name
}

output "state_bucket_arn" {
  value = aws_s3_bucket.state.arn
}
