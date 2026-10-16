# =============================================================================
# INPUT VARIABLES for the dev environment
# =============================================================================
# Values that might change between environments (dev, test, prod) live here,
# so the modules themselves never need editing.

variable "region" {
  description = "AWS region to build in"
  type        = string
  default     = "eu-west-2"
}

variable "project" {
  description = "Project name, used as a prefix for resource names and in tags"
  type        = string
  default     = "cis-hardened-server"
}

variable "owner" {
  description = "Owner tag value"
  type        = string
  default     = "Obiku"
}

variable "name_prefix" {
  description = "Short prefix for resource Name tags (matches the console build)"
  type        = string
  default     = "cis"
}
