# Account B — parameter owner (KMS key, parameters, RAM share)

# ---------------------------------------------------------------------------
# Owner KMS key (account B)
# ---------------------------------------------------------------------------

resource "aws_kms_key" "parameters" {
  provider = aws.owner

  description             = "Customer managed key for cross-account shared SecureString parameters"
  deletion_window_in_days = 7
  enable_key_rotation     = true

  # A SecureString can only be shared when it is encrypted with a customer
  # managed key, and the key must be authorized separately: the RAM share never
  # grants kms:Decrypt. The AWS managed key aws/ssm cannot be shared at all.
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        # Without this statement the key cannot be managed by the owner
        # account's own IAM policies. Resource "*" means "this key".
        Sid       = "EnableOwnerAccountIAMPolicies"
        Effect    = "Allow"
        Principal = { AWS = "arn:aws:iam::${var.owner_account_id}:root" }
        Action    = "kms:*"
        Resource  = "*"
      },
      {
        Sid       = "AllowConsumerRoleToDecrypt"
        Effect    = "Allow"
        Principal = { AWS = aws_iam_role.parameter_reader.arn }
        Action    = ["kms:Decrypt", "kms:DescribeKey"]
        Resource  = "*"
      },
    ]
  })
}

resource "aws_kms_alias" "parameters" {
  provider = aws.owner

  name          = "alias/${trimprefix(var.parameter_prefix, "/")}-parameters"
  target_key_id = aws_kms_key.parameters.key_id
}

# ---------------------------------------------------------------------------
# Owner parameters (account B)
# ---------------------------------------------------------------------------

resource "aws_ssm_parameter" "config" {
  provider = aws.owner

  # Standard tier parameters are not shareable at all: RAM's resource type is
  # Parameter Store Advanced Parameters, so tier = "Advanced" is mandatory.
  name        = "${var.parameter_prefix}/config"
  description = "Internal API endpoint shared with the workload account"
  type        = "String"
  tier        = "Advanced"
  value       = "https://api.example.internal"
}

resource "aws_ssm_parameter" "features" {
  provider = aws.owner

  name        = "${var.parameter_prefix}/features"
  description = "Comma-separated feature flags shared with the workload account"
  type        = "StringList"
  tier        = "Advanced"
  value       = "feature-a,feature-b,feature-c"
}

resource "aws_ssm_parameter" "secret" {
  provider = aws.owner

  name        = "${var.parameter_prefix}/secret"
  description = "Placeholder shared secret encrypted with the customer managed key"
  type        = "SecureString"
  tier        = "Advanced"
  key_id      = aws_kms_key.parameters.arn
  value       = "REPLACE_ME_placeholder_value"
}

# ---------------------------------------------------------------------------
# RAM resource share (account B)
# ---------------------------------------------------------------------------

locals {
  shared_parameter_arns = {
    config   = aws_ssm_parameter.config.arn
    features = aws_ssm_parameter.features.arn
    secret   = aws_ssm_parameter.secret.arn
  }
}

resource "aws_ram_resource_share" "parameters" {
  provider = aws.owner

  name = "${trimprefix(var.parameter_prefix, "/")}-parameters"

  # Both accounts are in the same organization, so external principals stay
  # disabled and no share invitation is created for the consumer to accept.
  allow_external_principals = false
  permission_arns           = [var.ram_permission_arn]

  tags = {
    Name = "${trimprefix(var.parameter_prefix, "/")}-parameters"
  }
}

resource "aws_ram_resource_association" "parameters" {
  provider = aws.owner

  for_each = local.shared_parameter_arns

  resource_arn       = each.value
  resource_share_arn = aws_ram_resource_share.parameters.arn
}

resource "aws_ram_principal_association" "consumer_role" {
  provider = aws.owner

  # Least privilege: the principal is the consumer EC2 instance role, not the
  # consumer account ID, so no other identity in account A gains access.
  principal          = aws_iam_role.parameter_reader.arn
  resource_share_arn = aws_ram_resource_share.parameters.arn
}
