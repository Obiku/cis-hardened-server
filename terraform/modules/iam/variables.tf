# Inputs to the iam module. Values are passed in from envs/dev/main.tf.

variable "name_prefix" {
  description = "Prefix for names, for example cis"
  type        = string
}

variable "evidence_bucket_arn" {
  description = "ARN of the evidence bucket the server uploads to"
  type        = string
}

variable "kms_key_arn" {
  description = "ARN of the KMS key the evidence is encrypted with"
  type        = string
}
