terraform {
  backend "s3" {
    bucket         = "async-msg-proc-tfstate-<ACCOUNT_ID>"
    key            = "envs/dev/terraform.tfstate"
    region         = "eu-west-1"
    dynamodb_table = "async-msg-proc-tfstate-locks"
    encrypt        = true
  }
}
