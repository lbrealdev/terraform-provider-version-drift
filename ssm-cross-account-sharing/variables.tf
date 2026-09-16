variable "region" {
  description = "AWS region for all resources. The owner and consumer accounts must be in the same region; Parameter Store sharing is not cross-region."
  type        = string
  default     = "us-east-1"
}

variable "owner_account_id" {
  description = "Placeholder AWS account ID of the parameter owner (account B). Replace with your own."
  type        = string
  default     = "111111111111"
}

variable "owner_assume_role_arn" {
  description = "Placeholder ARN of the role Terraform assumes in the owner account to create the parameters, the KMS key, and the RAM share."
  type        = string
  default     = "arn:aws:iam::111111111111:role/terraform-ssm-parameter-owner"
}

variable "consumer_assume_role_arn" {
  description = "Placeholder ARN of the role Terraform assumes in the consumer account (account A) to create the EC2 instance role."
  type        = string
  default     = "arn:aws:iam::222222222222:role/terraform-ssm-parameter-consumer"
}

variable "parameter_prefix" {
  description = "Parameter Store path prefix for the shared parameters. Must not be a reserved namespace: names beginning with aws or ssm cannot be shared."
  type        = string
  default     = "/shared-app"
}

variable "consumer_role_name" {
  description = "Name of the EC2 instance role created in the consumer account. This role is the RAM share principal, so only it gains access, not the whole account."
  type        = string
  default     = "shared-app-ec2-parameter-reader"
}

variable "ram_permission_arn" {
  description = "AWS managed RAM permission attached to the resource share. Use AWSRAMPermissionSSMParameterReadOnlyWithHistory instead to also allow GetParameterHistory. Omitting permission_arns entirely makes RAM attach the default for ssm:Parameter."
  type        = string
  default     = "arn:aws:ram::aws:permission/AWSRAMDefaultPermissionSSMParameterReadOnly"
}
