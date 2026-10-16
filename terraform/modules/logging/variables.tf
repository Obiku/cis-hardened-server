# Inputs to the logging module. Values are passed in from envs/dev/main.tf.

variable "kms_key_arn" {
  description = "ARN of the KMS key the log groups are encrypted with"
  type        = string
}

variable "retention_days" {
  description = "How many days CloudWatch keeps the logs"
  type        = number
  default     = 7
}
