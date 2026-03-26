terraform {
  backend "s3" {
    bucket         = "async-msg-proc-prod-messages-371670420772"
    key            = "terraform/envs/prod/terraform.tfstate"
    region         = "eu-west-1"
    dynamodb_table = "async-msg-proc-tfstate-locks"
    encrypt        = true
  }
}
