# Terraform Provider Version Drift

Collection of minimal Terraform configurations demonstrating provider version drift issues.

## Cases

- [**lambda-runtime-error**](lambda-runtime-error/) — AWS provider `4.25.0` rejects `python3.12` runtime due to enum mismatch
- [**s3-deprecation-migration**](s3-deprecation-migration/) — Manual migration from deprecated S3 bucket arguments to modern resource blocks
