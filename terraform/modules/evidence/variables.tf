# Inputs to the evidence module. Values are passed in from envs/dev/main.tf.

variable "bucket_name" {
  description = "Name of the evidence bucket (must be unique worldwide)"
  type        = string
}

variable "kms_key_arn" {
  description = "ARN of the KMS key used for default bucket encryption"
  type        = string
}
