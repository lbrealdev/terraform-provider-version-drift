# S3 Bucket Deprecation Migration

This case demonstrates migrating from deprecated S3 bucket arguments to modern resource blocks using a boolean flag.

## Context

AWS provider version 4.0 uses deprecated arguments for bucket configuration. This case shows how to migrate step-by-step while keeping the bucket intact.

## Boolean Flag

```bash
create_modern_resources = false  # Use deprecated arguments (default)
create_modern_resources = true  # Use modern resource blocks
```

## Deprecated Arguments to Modern Resources Mapping

| Deprecated Argument | Modern Resource |
|---------------------|-----------------|
| `acl` | `aws_s3_bucket_acl` |
| `logging` | `aws_s3_bucket_logging` |
| `versioning` | `aws_s3_bucket_versioning` |
| `lifecycle_rule` | `aws_s3_bucket_lifecycle_configuration` |

## Deprecation Warnings

When running `terraform plan` with deprecated arguments, Terraform displays warnings for each deprecated configuration:

```text
╷
│ Warning: Argument is deprecated
│
│   with aws_s3_bucket.example,
│   on main.tf line 9, in resource "aws_s3_bucket" "example":
│    9: resource "aws_s3_bucket" "example" {
│
│ Use the aws_s3_bucket_versioning resource instead
│
│ (and 3 more similar warnings elsewhere)
╵
```

## Migration Steps

### Step 1: Create Bucket with Deprecated Arguments

```bash
terraform init
terraform apply -var="create_modern_resources=false"
```

Expected output:
- Bucket created with `acl`, `logging`, `versioning`, and `lifecycle_rule` arguments
- Deprecation warnings shown for each argument

### Step 2: Migrate to Modern Resources

```bash
terraform apply -var="create_modern_resources=true"
```

Expected output:
- Bucket recreation managed by `count` meta-argument
- Modern resource blocks created to replace deprecated arguments

## Validation

After final apply:
- `terraform plan` should show no destruction of existing resources
- Only new resources should be created
- Bucket remains functional with same name

## Commands Summary

```bash
# Step 1: Create with deprecated arguments
terraform init
terraform apply -var="create_modern_resources=false"

# Step 2: Migrate to modern resources
terraform apply -var="create_modern_resources=true"
```

## Files

- `main.tf` - S3 bucket configuration with boolean-controlled resources
- `versions.tf` - Provider version constraints
- `README.md` - This documentation