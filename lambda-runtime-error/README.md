# Lambda Runtime Enum Mismatch

Minimal Terraform configuration reproducing an AWS provider version drift error.

## Context

A Lambda function was manually deployed or updated to use `python3.12`, but the Terraform module pins the AWS provider to `4.25.0`. When running `terraform plan` or `terraform apply`, the following error occurs:

```
╷
│ Error: expected runtime to be one of [nodejs nodejs4.3 nodejs6.10 nodejs8.10 nodejs10.x nodejs12.x nodejs14.x nodejs16.x java8 java8.al2 java11 python2.7 python3.6 python3.7 python3.8 python3.9 dotnetcore1.0 dotnetcore2.0 dotnetcore2.1 dotnetcore3.1 dotnet6 nodejs4.3-edge go1.x ruby2.5 ruby2.7 provided provided.al2], got python3.12
│
│   with aws_lambda_function.test,
│   on main.tf line 32, in resource "aws_lambda_function" "test":
│   32:   runtime          = "python3.12"
│
╵
```

## Root Cause

The AWS Terraform provider version constrains which Lambda runtimes are recognized as valid. Provider `4.25.0` predates `python3.12`, so it rejects the runtime even though AWS Lambda itself supports it.

## Fix

Upgrade the AWS provider to `~> 5.0` (or any version that includes `python3.12` in its runtime enum). In `versions.tf`:

```hcl
required_providers {
  aws = {
    source  = "hashicorp/aws"
    version = "~> 5.0"
  }
}
```

Then run:

```bash
terraform init -upgrade
terraform plan
terraform apply
```

## Structure

- `versions.tf` — Terraform and provider version constraints
- `main.tf` — IAM role, Lambda function, and zip archive data source
- `lambda_function.py` — Simple Python handler

## Reproducing the Error

To reproduce the error, pin the AWS provider to `~> 4.25.0` in `versions.tf` and run:

```bash
terraform init
terraform plan
```
