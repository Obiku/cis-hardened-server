# Inputs to the monitoring module. Values are passed in from envs/dev/main.tf.

variable "account_id" {
  description = "AWS account ID, used in the Config bucket name and policy"
  type        = string
}

variable "region" {
  description = "AWS region, used in the Security Hub standard ARN"
  type        = string
}
