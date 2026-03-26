# AWS Async Message Processor

Production-oriented async message processing system on AWS:

- **Producer**: FastAPI service receives HTTP payloads, validates schema + token, pushes to SQS.
- **Consumer**: Async worker long-polls SQS, writes messages to S3, then deletes from queue.
- **Infra**: Terraform modules + env roots (`dev`/`prod`).
- **CI/CD**: GitHub Actions with reusable service pipeline for unit tests, integration tests, image build/push, and ECS deploy.

---

## Why this architecture

### Free Tier constraints

All resources are chosen to stay within Free Tier boundaries where possible:

- ECS on **EC2** (`t2.micro`) instead of Fargate
- Classic Load Balancer instead of ALB
- SQS + DLQ
- S3 + SSE
- CloudWatch + SNS email alerts

I intentionally did **not** use ECS Fargate because it is not Free Tier eligible for this assignment scope.

### Terraform state choice (local state)

This repo uses **local Terraform state** for `dev` and `prod`.

Reason: in this account/org, `s3:PutBucketPublicAccessBlock` is denied by SCP, so creating a hardened remote-state S3 bucket via Terraform fails.  
If that policy restriction did not exist, I would use the standard production approach:

- S3 backend for state
- DynamoDB table for state locking

---

## Core AWS building blocks

- **SQS + DLQ**: main queue with dead-letter queue for failed messages
- **S3 bucket**: stores processed payloads
- **SSM Parameter Store**:
  - validation token (SecureString)
  - runtime app configs (queue url, bucket name, polling settings)

Using SSM for app config decouples configuration from Git and allows easy updates without code changes.

---

## Monitoring and alerting

Monitoring is implemented with:

- **CloudWatch Logs** (application logs)
- **CloudWatch Dashboard** (ECS/SQS/CLB visibility)
- **CloudWatch Alarms** (service health, queue backlog, DLQ, age)
- **SNS email notifications** for alarms and deployment notifications

---

## Application implementation notes

### Producer (FastAPI)

- FastAPI endpoint with Pydantic model validation
- Request-body token validation against SSM value
- Async publish to SQS via `aioboto3`
- Validation token is cached in memory to avoid repeated SSM calls
- Type hints + docstrings throughout

### Consumer (async worker)

- Async long polling from SQS (`WaitTimeSeconds` configurable)
- Processes payload and writes JSON object to S3
- Deletes successfully processed messages from queue
- Type hints + docstrings throughout

### Shared code and logging

- Custom shared logger in `services/shared/logging_setup.py`
- Structured log format with service metadata
- Reused by both producer and consumer services

### AWS SDK/session usage

- Uses `aioboto3` for async AWS interactions
- Reuses boto session/client lifecycle where appropriate

---

## Tests

### Unit tests

- Pytest for both services
- `moto`/mocking for AWS behavior
- No real cloud dependency intended for unit paths

### Integration tests

- Run against built Docker images/containers
- Validate real app behavior in container runtime
- Service-specific integration checks for producer/consumer

---

## Docker

Both service Dockerfiles use Python **slim** base images to reduce image size and startup overhead.

---

## CI/CD design

### Decoupled service pipelines

Producer and consumer are decoupled using path filtering, so only changed service pipelines run.

### Reusable template pipeline

`_service-pipeline.yml` is the reusable workflow template used by CI/CD:

1. Unit tests
2. Docker build
3. Integration tests
4. Optional ECR push

Integration tests are conceptually a separate stage from image build. In this project they are intentionally executed in the same reusable workflow/job sequence on GitHub-hosted runners, so the already-built image can be reused immediately and only successful images are pushed to ECR. This reduces duplicate build/push cycles and helps control CI/CD cost and registry churn.

### CI

- Runs service verification flow (unit + build + integration)
- No image push, no deployment

### CD

- Runs same verification flow
- Pushes image(s) to ECR
- Deploys changed ECS service(s)
- Waits for service stability
- Includes rollback detection by comparing task definition before/after deployment

---

## Runtime configuration updates (no Git change)

App config values are in SSM. To update behavior:

1. Update SSM parameter value
2. Force ECS new deployment so tasks restart and read updated values

Example:

```bash
aws ecs update-service \
  --cluster <cluster-name> \
  --service <producer-or-consumer-service> \
  --force-new-deployment \
  --region eu-west-1
```

---

## How to deploy

### 1) Terraform infrastructure (local)

```bash
cd terraform/envs/prod
terraform init
terraform plan
terraform apply
```

For dev:

```bash
cd terraform/envs/dev
terraform init
terraform plan
terraform apply
```

### 2) Build/deploy app via GitHub Actions

- Push code / open PR depending on your current workflow triggers.
- CI verifies changed services.
- CD builds, pushes to ECR, and deploys to ECS for changed services.

Required GitHub secrets/vars include (as configured in workflows):

- `AWS_ACCESS_KEY_ID`
- `AWS_SECRET_ACCESS_KEY`
- `VALIDATION_TOKEN` (for Terraform `TF_VAR_validation_token`)
- optional `SNS_TOPIC_ARN`
- vars such as region/cluster name used by workflows

---

## Simple Python script to test the app

After infra + app deployment, call producer through the load balancer:

```python
import json
import requests

CLB_DNS = "http://async-msg-proc-dev-clb-1096803901.eu-west-1.elb.amazonaws.com"
TOKEN = "<your-validation-token>" //as displayed in the exam pdf example

payload = {
    "data": {
        "email_subject": "Hello",
        "email_sender": "tester@example.com",
        "email_timestream": "1700000000",
        "email_content": "Smoke test message"
    },
    "token": TOKEN
}

resp = requests.post(f"{CLB_DNS}/messages", json=payload, timeout=15)
print(resp.status_code)
print(json.dumps(resp.json(), indent=2))
```

Expected:

- HTTP `202`
- JSON response with `status: accepted`

---

## Notes for evaluators

- The design intentionally balances production patterns with Free Tier constraints.
- Local Terraform state is a practical fallback here due to account SCP restrictions around public-access-block API calls on S3.
- If policy permits, switching to S3+DynamoDB backend is straightforward.
