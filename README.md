# Terraform AWS Problem-Solutions

Collection of minimal Terraform configurations demonstrating AWS provider issues and solutions.

## Cases

- [**lambda-runtime-error**](lambda-runtime-error) — AWS provider `4.25.0` rejects `python3.12` runtime due to enum mismatch
- [**s3-deprecation-migration**](s3-deprecation-migration) — Manual migration from deprecated S3 bucket arguments to modern resource blocks
- [**ssm-cross-account-sharing**](ssm-cross-account-sharing) — Cross-account SSM Parameter Store sharing with Advanced-tier parameters, AWS RAM, and a customer managed KMS key

## Command Reference

This repository uses `just` for task automation. Available commands for solution directories:

- `just init SOLUTION` — Initialize Terraform in solution directory
- `just plan SOLUTION [args]` — Generate Terraform plan with optional variables
- `just apply SOLUTION [args]` — Apply Terraform plan with optional variables
- `just destroy SOLUTION [args]` — Destroy all Terraform resources
- `just validate SOLUTION` — Validate Terraform configuration
- `just fmt SOLUTION` — Format Terraform files
- `just docs SOLUTION` — Generate Terraform documentation
- `just show SOLUTION` — Show Terraform state
- `just state SOLUTION` — List Terraform state resources
- `just refresh SOLUTION` — Refresh Terraform state

### Solution-specific Commands

**s3-deprecation-migration/** only:
- `just deprecate` — Toggle deprecated arguments (lines 39-70) in main.tf