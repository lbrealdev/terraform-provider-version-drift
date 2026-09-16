# Account A — consumer (IAM role, policy, reads)

# ---------------------------------------------------------------------------
# Consumer IAM role (account A)
# ---------------------------------------------------------------------------
# The inline policy is a separate resource on purpose: folding it into the role
# would create a cycle, since it references the key the key policy references.

resource "aws_iam_role" "parameter_reader" {
  provider = aws.consumer

  name = var.consumer_role_name

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_instance_profile" "parameter_reader" {
  provider = aws.consumer

  name = var.consumer_role_name
  role = aws_iam_role.parameter_reader.name
}

# ---------------------------------------------------------------------------
# Consumer inline policy (account A)
# ---------------------------------------------------------------------------

resource "aws_iam_role_policy" "parameter_reader" {
  provider = aws.consumer

  name = "read-shared-parameters"
  role = aws_iam_role.parameter_reader.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        # DescribeParameters supports no resource types, so it must be granted
        # on "*". Scoping it to a parameter ARN silently denies the call.
        Sid      = "ListSharedParameters"
        Effect   = "Allow"
        Action   = "ssm:DescribeParameters"
        Resource = "*"
      },
      {
        # Owner-account ARNs. RAM makes the parameters reachable from account A;
        # IAM in account A still has to allow the API call itself.
        Sid      = "ReadSharedParameters"
        Effect   = "Allow"
        Action   = ["ssm:GetParameter", "ssm:GetParameters"]
        Resource = "${local.owner_parameter_arn_prefix}/*"
      },
      {
        Sid      = "DecryptSharedSecureString"
        Effect   = "Allow"
        Action   = "kms:Decrypt"
        Resource = aws_kms_key.parameters.arn
      },
    ]
  })
}

# ---------------------------------------------------------------------------
# Consumer reads (account A, illustrative)
# ---------------------------------------------------------------------------

# Shared parameters must be read by their full owner-account ARN. Passing the
# short name "/shared-app/config" resolves against the consumer account and
# fails with ParameterNotFound.
data "aws_ssm_parameter" "shared_config" {
  provider = aws.consumer

  name = aws_ssm_parameter.config.arn

  depends_on = [
    aws_ram_resource_association.parameters,
    aws_ram_principal_association.consumer_role,
    aws_iam_role_policy.parameter_reader,
  ]
}

data "aws_ssm_parameter" "shared_secret" {
  provider = aws.consumer

  name            = aws_ssm_parameter.secret.arn
  with_decryption = true

  depends_on = [
    aws_ram_resource_association.parameters,
    aws_ram_principal_association.consumer_role,
    aws_iam_role_policy.parameter_reader,
  ]
}
