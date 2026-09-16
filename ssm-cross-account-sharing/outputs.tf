output "consumer_role_arn" {
  description = "ARN of the consumer EC2 instance role. This is the RAM share principal — the share is granted to this role, not to the consumer account as a whole."
  value       = aws_iam_role.parameter_reader.arn
}

output "kms_key_arn" {
  description = "ARN of the customer managed key that encrypts the shared SecureString. The RAM share never grants kms:Decrypt; this key is the other silent cross-account failure point."
  value       = aws_kms_key.parameters.arn
}

output "ram_resource_share_arn" {
  description = "ARN of the RAM resource share that lists the three parameters. The consumer's illustrative reads depend on this share being associated before they can succeed."
  value       = aws_ram_resource_share.parameters.arn
}

output "shared_parameter_arns" {
  description = "Map of the three shared parameter ARNs in the owner account. Reads from the consumer account must use these full ARNs; the short name resolves against the caller and returns ParameterNotFound."
  value       = local.shared_parameter_arns
}
