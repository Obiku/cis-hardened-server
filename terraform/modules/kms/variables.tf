# Inputs to the kms module. Values are passed in from envs/dev/main.tf.

variable "key_alias" {
  description = "Alias for the key, without the alias/ prefix"
  type        = string
}

variable "account_id" {
  description = "AWS account ID, used in the key policy"
  type        = string
}

variable "region" {
  description = "AWS region, used in the CloudWatch Logs statement"
  type        = string
}
