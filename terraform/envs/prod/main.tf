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
      Project     = var.project_name
      Environment = var.environment
      ManagedBy   = "terraform"
    }
  }
}

data "aws_caller_identity" "current" {}

locals {
  name = "${var.project_name}-${var.environment}"
}

# ── Networking ──────────────────────────────────────────────────

module "networking" {
  source = "../../modules/networking"

  name                    = local.name
  vpc_cidr                = var.vpc_cidr
  public_subnet_cidrs     = var.public_subnet_cidrs
  availability_zones      = var.availability_zones
  producer_container_port = 8000
}

# ── CLB (Classic Load Balancer – Free Tier) ─────────────────────

module "lb" {
  source = "../../modules/alb"

  name                 = local.name
  public_subnet_ids    = module.networking.public_subnet_ids
  lb_security_group_id = module.networking.lb_security_group_id
  container_port       = 8000
}

# ── SQS ─────────────────────────────────────────────────────────

module "sqs" {
  source = "../../modules/sqs"
  name   = local.name
}

# ── S3 ──────────────────────────────────────────────────────────

module "s3" {
  source = "../../modules/s3"

  name       = local.name
  account_id = data.aws_caller_identity.current.account_id
}

# ── ECR ─────────────────────────────────────────────────────────

module "ecr" {
  source = "../../modules/ecr"
  name   = local.name
}

# ── SSM ─────────────────────────────────────────────────────────

module "ssm" {
  source = "../../modules/ssm"

  name                           = local.name
  project_name                   = var.project_name
  environment                    = var.environment
  validation_token               = var.validation_token
  producer_sqs_queue_url         = module.sqs.queue_url
  consumer_sqs_queue_url         = module.sqs.queue_url
  consumer_s3_bucket_name        = module.s3.bucket_id
  consumer_sqs_wait_time_seconds = 20
  consumer_sqs_max_messages      = 10
}

# ── IAM ─────────────────────────────────────────────────────────

module "iam" {
  source = "../../modules/iam"

  name              = local.name
  aws_region        = var.aws_region
  account_id        = data.aws_caller_identity.current.account_id
  ecr_producer_arn  = module.ecr.producer_repository_arn
  ecr_consumer_arn  = module.ecr.consumer_repository_arn
  ssm_parameter_arn = module.ssm.parameter_arn
  execution_ssm_parameter_arns = [
    module.ssm.producer_sqs_queue_url_arn,
    module.ssm.consumer_sqs_queue_url_arn,
    module.ssm.consumer_s3_bucket_name_arn,
    module.ssm.consumer_sqs_wait_time_seconds_arn,
    module.ssm.consumer_sqs_max_messages_arn
  ]
  sqs_queue_arn    = module.sqs.queue_arn
  s3_bucket_arn    = module.s3.bucket_arn
  log_group_prefix = "/ecs/${local.name}"
  ecs_cluster_name = "${local.name}-cluster"
}

# ── ECS (cluster + EC2 instances + services + autoscaling) ──────

module "ecs" {
  source = "../../modules/ecs"

  name                  = local.name
  aws_region            = var.aws_region
  public_subnet_ids     = module.networking.public_subnet_ids
  ecs_security_group_id = module.networking.ecs_security_group_id

  execution_role_arn       = module.iam.ecs_task_execution_role_arn
  producer_task_role_arn   = module.iam.producer_task_role_arn
  consumer_task_role_arn   = module.iam.consumer_task_role_arn
  ecs_instance_profile_arn = module.iam.ecs_instance_profile_arn

  instance_type        = "t2.micro"
  asg_min_size         = 1
  asg_max_size         = 1
  asg_desired_capacity = 1

  producer_image = "${module.ecr.producer_repository_url}:${var.producer_image_tag}"
  consumer_image = "${module.ecr.consumer_repository_url}:${var.consumer_image_tag}"

  sqs_queue_name                         = module.sqs.queue_name
  ssm_parameter_name                     = module.ssm.parameter_name
  producer_sqs_queue_url_ssm_arn         = module.ssm.producer_sqs_queue_url_arn
  consumer_sqs_queue_url_ssm_arn         = module.ssm.consumer_sqs_queue_url_arn
  consumer_s3_bucket_name_ssm_arn        = module.ssm.consumer_s3_bucket_name_arn
  consumer_sqs_wait_time_seconds_ssm_arn = module.ssm.consumer_sqs_wait_time_seconds_arn
  consumer_sqs_max_messages_ssm_arn      = module.ssm.consumer_sqs_max_messages_arn

  clb_name = module.lb.clb_name

  producer_cpu           = 128
  producer_memory        = 384
  consumer_cpu           = 128
  consumer_memory        = 384
  producer_desired_count = 1
  consumer_desired_count = 1
  producer_max_count     = 2
  consumer_max_count     = 2
  log_retention_days     = 7
}

# ── Monitoring (CloudWatch dashboard + alarms + SNS) ─────────────

module "monitoring" {
  source = "../../modules/monitoring"

  name       = local.name
  aws_region = var.aws_region

  alert_email = var.alert_email

  ecs_cluster_name      = module.ecs.cluster_name
  producer_service_name = module.ecs.producer_service_name
  consumer_service_name = module.ecs.consumer_service_name
  sqs_queue_name        = module.sqs.queue_name
  dlq_name              = module.sqs.dlq_name
  clb_name              = module.lb.clb_name
}
