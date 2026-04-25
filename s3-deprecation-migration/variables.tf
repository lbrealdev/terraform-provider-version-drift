variable "region" {
  description = "AWS region for resources"
  type        = string
  default     = "eu-central-1"
}

variable "create_modern_resources" {
  description = "Set to true to create modern resource blocks instead of using deprecated arguments"
  type        = bool
  default     = false
}
