###############################################################################
# Bootstrap – provisions the S3 bucket and DynamoDB table used by all
# environment backends for remote Terraform state.
#
# Run once:
#   cd terraform/envs/_bootstrap
#   terraform init && terraform apply
#
# This config intentionally uses LOCAL state – it is the one piece of infra
# that cannot store its own state remotely (chicken-and-egg).
###############################################################################

terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project   = var.project_name
      ManagedBy = "terraform"
      Purpose   = "tf-state"
    }
  }
}

data "aws_caller_identity" "current" {}

# ── S3 Bucket for State ─────────────────────────────────────────

resource "aws_s3_bucket" "state" {
  bucket = "${var.project_name}-tfstate-${data.aws_caller_identity.current.account_id}"

  lifecycle {
    prevent_destroy = true
  }

  tags = { Name = "${var.project_name}-tfstate" }
}

resource "aws_s3_bucket_versioning" "state" {
  bucket = aws_s3_bucket.state.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "state" {
  bucket = aws_s3_bucket.state.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
    bucket_key_enabled = true
  }
}


# ── DynamoDB Table for State Locking ─────────────────────────────

resource "aws_dynamodb_table" "tf_locks" {
  name         = "${var.project_name}-tfstate-locks"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }

  lifecycle {
    prevent_destroy = true
  }

  tags = { Name = "${var.project_name}-tfstate-locks" }
}
