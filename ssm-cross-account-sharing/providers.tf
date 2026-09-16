# ---------------------------------------------------------------------------
# Providers
# ---------------------------------------------------------------------------
# There is no default provider block: every resource and data block below must
# name aws.owner or aws.consumer explicitly.

provider "aws" {
  alias  = "owner"
  region = var.region

  assume_role {
    role_arn     = var.owner_assume_role_arn
    session_name = "terraform-ssm-parameter-owner"
  }
}

provider "aws" {
  alias  = "consumer"
  region = var.region

  assume_role {
    role_arn     = var.consumer_assume_role_arn
    session_name = "terraform-ssm-parameter-consumer"
  }
}

locals {
  # Shared parameters are always read by their ARN in the OWNER account. SSM
  # absorbs the leading slash of the name when it builds the ARN, so
  # /shared-app/config becomes ...:parameter/shared-app/config.
  owner_parameter_arn_prefix = "arn:aws:ssm:${var.region}:${var.owner_account_id}:parameter${var.parameter_prefix}"
}
