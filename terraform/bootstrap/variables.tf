# Input variables: values that can change without editing the code.
# Each has a default, so "terraform apply" works without extra input.

variable "region" {
  description = "AWS region for the state bucket"
  type        = string
  default     = "eu-west-2"
}

variable "project" {
  description = "Project name, used in resource names and the Project tag"
  type        = string
  default     = "cis-hardened-server"
}

variable "owner" {
  description = "Owner tag value"
  type        = string
  default     = "Obiku"
}
