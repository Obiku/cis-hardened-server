# Inputs to the network module. Values are passed in from envs/dev/main.tf.

variable "name_prefix" {
  description = "Prefix for Name tags, for example cis"
  type        = string
}

variable "region" {
  description = "AWS region, used to build endpoint service names"
  type        = string
}

variable "availability_zone" {
  description = "Availability Zone for both subnets"
  type        = string
  default     = "eu-west-2a"
}

variable "vpc_cidr" {
  description = "IP range for the VPC"
  type        = string
  default     = "10.20.0.0/16"
}

variable "public_subnet_cidr" {
  description = "IP range for the public subnet (NAT gateway only)"
  type        = string
  default     = "10.20.0.0/24"
}

variable "private_subnet_cidr" {
  description = "IP range for the private subnet (the server)"
  type        = string
  default     = "10.20.1.0/24"
}
