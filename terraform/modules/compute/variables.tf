# Inputs to the compute module. Values are passed in from envs/dev/main.tf.

variable "name_prefix" {
  description = "Prefix for the Name tag, for example cis"
  type        = string
}

variable "region" {
  description = "AWS region, used to download the CloudWatch agent"
  type        = string
}

variable "subnet_id" {
  description = "Private subnet the server is launched in"
  type        = string
}

variable "security_group_id" {
  description = "Security group for the server"
  type        = string
}

variable "instance_profile_name" {
  description = "Instance profile that attaches the server role"
  type        = string
}

variable "kms_key_arn" {
  description = "ARN of the KMS key for the disk and EBS default encryption"
  type        = string
}

variable "instance_type" {
  description = "EC2 instance size"
  type        = string
  default     = "t3.micro"
}
