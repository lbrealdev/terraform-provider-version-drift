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

| Deprecated Argument | Modern Resource                         |
|---------------------|-----------------------------------------|
| `acl`               | `aws_s3_bucket_acl`                     |
| `logging`           | `aws_s3_bucket_logging`                 |
| `versioning`        | `aws_s3_bucket_versioning`              |
| `lifecycle_rule`    | `aws_s3_bucket_lifecycle_configuration` |

## Deprecation Warnings

When running `terraform plan` with deprecated arguments, Terraform displays warnings for each deprecated configuration:

```shell
╷
│ Warning: Argument is deprecated
│
│   with aws_s3_bucket.example,
│   on main.tf line 9, in resource "aws_s3_bucket" "example":
│    9: resource "aws_s3_bucket" "example" {

│ Use the aws_s3_bucket_versioning resource instead
│
│ (and 3 more similar warnings elsewhere)
╵
```

## Complete Reproduction Flow

This proof of concept demonstrates the complete migration process using the `justfile` recipes:

### Step 1: Create initial bucket with deprecated arguments

```shell
# Initialize and apply with default settings (deprecated arguments)
just init s3-deprecation-migration
just plan s3-deprecation-migration
just apply s3-deprecation-migration
```

Expected output:

**Plan output:**
```shell
Plan: 3 to add, 0 to change, 0 to destroy.
╷
│ Warning: Argument is deprecated
│
│   with aws_s3_bucket.main,
│   on main.tf line 18, in resource "aws_s3_bucket" "main":
│   18: resource "aws_s3_bucket" "main" {
│
│ Use the aws_s3_bucket_versioning resource instead
│
│ (and 2 more similar warnings elsewhere)
╵

───────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────

Saved the plan to: plan

To perform exactly these actions, run the following command to apply:
    terraform apply "plan"
```

**Apply output:**
```shell
random_id.bucket_suffix: Creating...
random_id.bucket_suffix: Creation complete after 0s [id=Gb5HbA]
aws_s3_bucket.logging_target: Creating...
aws_s3_bucket.logging_target: Creation complete after 2s [id=my-access-logs-bucket-19be476c]
aws_s3_bucket.main: Creating...
aws_s3_bucket.main: Creation complete after 3s [id=my-app-logs-19be476c]
╷
│ Warning: Argument is deprecated
│
│   with aws_s3_bucket.main,
│   on main.tf line 18, in resource "aws_s3_bucket" "main":
│   18: resource "aws_s3_bucket" "main" {
│
│ Use the aws_s3_bucket_versioning resource instead
│
│ (and 3 more similar warnings elsewhere)
╵

Apply complete! Resources: 3 added, 0 changed, 0 destroyed.
```

Expected behavior:
- Bucket created with `acl`, `logging`, `versioning`, and `lifecycle_rule` arguments
- Deprecation warnings shown for each argument
- Two buckets created: `my-app-logs-{random}` and `my-access-logs-{random}`

### Step 2: Toggle deprecated arguments for testing

```shell
# Comment out deprecated arguments in main.tf (lines 39-70)
just deprecate
```

Expected output:

**deprecate output:**
```shell
Deprecated arguments DISABLED
```

Expected behavior:
- Deprecated arguments DISABLED (now using modern resource blocks)
- Only modern resources will be created on next apply

### Step 3: Migrate to modern resources

```shell
# Apply with modern resource blocks enabled
just plan s3-deprecation-migration -var="create_modern_resources=true"
just apply s3-deprecation-migration -var="create_modern_resources=true"
```

Expected output:

**Plan output:**
```shell
random_id.bucket_suffix: Refreshing state... [id=Gb5HbA]
aws_s3_bucket.logging_target: Refreshing state... [id=my-access-logs-bucket-19be476c]
aws_s3_bucket.main: Refreshing state... [id=my-app-logs-19be476c]

Terraform used the selected providers to generate the following execution plan. Resource actions are indicated with the following symbols:
  + create

Terraform will perform the following actions:

  # aws_s3_bucket_acl.main[0] will be created
  + resource "aws_s3_bucket_acl" "main" {
      + acl    = "private"
      + bucket = "my-app-logs-19be476c"
      + id     = (known after apply)

      + access_control_policy (known after apply)
    }

  # aws_s3_bucket_lifecycle_configuration.main[0] will be created
  + resource "aws_s3_bucket_lifecycle_configuration" "main" {
      + bucket = "my-app-logs-19be476c"
      + id     = (known after apply)

      + rule {
          + id     = "archive-logs"
          + status = "Enabled"

          + expiration {
              + days                         = 365
              + expired_object_delete_marker = (known after apply)
            }

          + filter {
              + prefix = "logs/"
            }

          + transition {
              + days          = 30
              + storage_class = "STANDARD_IA"
                # (1 unchanged attribute hidden)
            }
          + transition {
              + days          = 90
              + storage_class = "GLACIER"
                # (1 unchanged attribute hidden)
            }
        }
    }

  # aws_s3_bucket_logging.main[0] will be created
  + resource "aws_s3_bucket_logging" "main" {
      + bucket        = "my-app-logs-19be476c"
      + id            = (known after apply)
      + target_bucket = "my-access-logs-bucket-19be476c"
      + target_prefix = "log/"
    }

  # aws_s3_bucket_ownership_controls.main[0] will be created
  + resource "aws_s3_bucket_ownership_controls" "main" {
      + bucket = "my-app-logs-19be476c"
      + id     = (known after apply)

      + rule {
          + object_ownership = "BucketOwnerPreferred"
        }
    }

  # aws_s3_bucket_versioning.main[0] will be created
  + resource "aws_s3_bucket_versioning" "main" {
      + bucket = "my-app-logs-19be476c"
      + id     = (known after apply)

      + versioning_configuration {
          + mfa_delete = (known after apply)
          + status     = "Enabled"
        }
    }

Plan: 5 to add, 0 to change, 0 to destroy.

───────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────

Saved the plan to: plan

To perform exactly these actions, run the following command to apply:
    terraform apply "plan"
```

**Apply output:**
```shell
aws_s3_bucket_versioning.main[0]: Creating...
aws_s3_bucket_lifecycle_configuration.main[0]: Creating...
aws_s3_bucket_ownership_controls.main[0]: Creating...
aws_s3_bucket_logging.main[0]: Creating...
aws_s3_bucket_logging.main[0]: Creation complete after 0s [id=my-app-logs-19be476c]
aws_s3_bucket_ownership_controls.main[0]: Creation complete after 1s [id=my-app-logs-19be476c]
aws_s3_bucket_acl.main[0]: Creating...
aws_s3_bucket_acl.main[0]: Creation complete after 0s [id=my-app-logs-19be476c,private]
aws_s3_bucket_versioning.main[0]: Creation complete after 1s [id=my-app-logs-19be476c]
aws_s3_bucket_lifecycle_configuration.main[0]: Still creating... [00m10s elapsed]
aws_s3_bucket_lifecycle_configuration.main[0]: Still creating... [00m20s elapsed]
aws_s3_bucket_lifecycle_configuration.main[0]: Still creating... [00m30s elapsed]
aws_s3_bucket_lifecycle_configuration.main[0]: Creation complete after 31s [id=my-app-logs-19be476c]

Apply complete! Resources: 5 added, 0 changed, 0 destroyed.
```

Expected output:
- Existing main bucket unchanged
- Modern resource blocks created to replace deprecated arguments
- Ownership controls added
- `aws_s3_bucket_acl.main` resource created (uses ownership controls instead)
- Two buckets created: `my-app-logs-{random}` and `my-access-logs-{random}`

### Step 4: Cleanup

```shell
# Destroy all created resources
just destroy s3-deprecation-migration -var="create_modern_resources=true"
```

Expected output:

**Destroy output:**
```shell
Plan: 0 to add, 0 to change, 8 to destroy.

───────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────

Saved the plan to: destroy

To perform exactly these actions, run the following command to apply:
    terraform apply "destroy"
Are you sure you want to destroy all Terraform resources? This action cannot be undone. y
aws_s3_bucket_logging.main[0]: Destroying... [id=my-app-logs-19be476c]
aws_s3_bucket_versioning.main[0]: Destroying... [id=my-app-logs-19be476c]
aws_s3_bucket_lifecycle_configuration.main[0]: Destroying... [id=my-app-logs-19be476c]
aws_s3_bucket_acl.main[0]: Destroying... [id=my-app-logs-19be476c,private]
aws_s3_bucket_acl.main[0]: Destruction complete after 0s
aws_s3_bucket_ownership_controls.main[0]: Destroying... [id=my-app-logs-19be476c]
aws_s3_bucket_logging.main[0]: Destruction complete after 1s
aws_s3_bucket_ownership_controls.main[0]: Destruction complete after 1s
aws_s3_bucket_lifecycle_configuration.main[0]: Destruction complete after 1s
aws_s3_bucket_versioning.main[0]: Destruction complete after 1s
aws_s3_bucket.main: Destroying... [id=my-app-logs-19be476c]
aws_s3_bucket.main: Destruction complete after 0s
aws_s3_bucket.logging_target: Destroying... [id=my-access-logs-bucket-19be476c]
aws_s3_bucket.logging_target: Destruction complete after 0s
random_id.bucket_suffix: Destroying... [id=Gb5HbA]
random_id.bucket_suffix: Destruction complete after 0s

Apply complete! Resources: 0 added, 0 changed, 8 destroyed.
```

Expected output:
- All Terraform resources destroyed
- Both S3 buckets removed

## Validation

After final apply:
- `terraform plan` should show no destruction of existing resources when migrating
- Only new resources should be created during migration
- Bucket remains functional with same name after migration
- No deprecation warnings with modern resources

## Files

- `main.tf` - S3 bucket configuration with deprecated and modern resource blocks controlled by boolean flag
- `variables.tf` - Input variables for region and create_modern_resources configuration
- `versions.tf` - AWS provider version constraints
- `README.md` - Complete reproduction flow documentation
